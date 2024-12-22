const std = @import("std");
const Chunk = @import("Chunk.zig");
const ValueArray = @import("ValueArray.zig");
const Compiler = @import("Compiler.zig");
const debug = @import("debug.zig");
const config = @import("config.zig");
const Value = @import("value.zig").Value;
const Object = @import("object.zig").Object;
const ObjString = @import("object.zig").ObjString;
const Opcode = Chunk.Opcode;
const Allocator = std.mem.Allocator;

/// A stack-based virtual machine struct.
/// Use `init()` to initialize the VM instance.
const VM = @This();

pub const InterpretResult = enum { INTERPRET_OK };
pub const InterpretError = error{ INTERPRET_COMPILE_ERROR, INTERPRET_RUNTIME_ERROR };

// TODO: consider making them struct fields rather than namespaced global variables?
pub const MMU = struct {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    pub const obj_allocator = gpa.allocator();
    pub var obj_list: ?*Object = null;

    /// Register a newly allocated object to the list so VM can free it via `freeObjects()`.
    pub inline fn register(object: *Object) void {
        object.next = obj_list;
        obj_list = object;
    }

    /// Free objects on the list.
    pub fn free() void {
        var it = obj_list;
        while (it) |obj| {
            const next = obj.next;
            obj.destroy(obj_allocator);
            it = next;
        }
    }
};

chunk: *Chunk,
ip: usize, // The intruction pointer points at the next byte to be read
stack: [config.stack_max]Value,
stack_top: usize, // This points at the first *not-in-use* element of the stack

pub fn init() VM {
    var self = VM{
        .chunk = undefined,
        .ip = undefined,
        .stack = undefined,
        .stack_top = undefined,
    };
    self.resetStack();
    return self;
}

pub fn deinit(self: *VM) void {
    defer _ = MMU.gpa.deinit();
    MMU.free();
    self.resetStack();
}

inline fn resetStack(self: *VM) void {
    self.stack_top = 0;
}

/// Runs VM in interactive mode, predominantly known as "REPL" (Read-Eval-Print-Loop).
/// Ends reading input after reading an `EOF` (of which input is 'Ctrl-D' in common shells).
pub fn repl(self: *VM) !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var buf: [1024]u8 = undefined;
    var br = std.io.bufferedReader(stdin);
    var reader = br.reader();
    while (true) {
        try stdout.print("> ", .{});

        if (reader.readUntilDelimiterOrEof(buf[0..], '\n') catch |err| {
            std.debug.print("Could not read input: {}\n", .{err});
            return err;
        }) |line| {
            _ = try self.interpret(line);
        } else {
            try stdout.print("\n", .{});
            break;
        }
    }
}

/// Runs VM which executes the given lox source code specified by `path`.
pub fn runFile(self: *VM, path: []const u8) !void {
    var buffer: [1024 * 1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    const source: []u8 = try readFile(path, allocator);
    _ = try self.interpret(source);
}

/// Reads out the file specified by `path` onto heap memory.
fn readFile(path: []const u8, allocator: Allocator) ![]u8 {
    var file = std.fs.cwd().openFile(path, .{}) catch |err| {
        std.debug.print("Could not open file: {} \"{s}\"\n", .{ err, path });
        return err;
    };
    return file.readToEndAlloc(allocator, 1024 * 1024) catch |err| {
        std.debug.print("Could not read file: {}\n", .{err});
        return err;
    }; // 1MB max
}

fn runtimeError(self: *VM, comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
    std.debug.print("\n", .{});

    const line = self.chunk.lines[self.ip - 1];
    std.debug.print("[line {}] in script\n", .{line});
    self.resetStack();
}

fn push(self: *VM, value: Value) void {
    self.stack[self.stack_top] = value;
    self.stack_top += 1;
}

fn pop(self: *VM) Value {
    self.stack_top -= 1;
    return self.stack[self.stack_top];
}

fn peek(self: *VM, distance: usize) Value {
    return self.stack[self.stack_top - 1 - distance];
}

/// Drives a pipeline to scan, compile, and execute the code.
/// Returns Error if an error occurs during compilation or runtime, otherwise returns ok.
pub fn interpret(self: *VM, source: []const u8) !InterpretResult {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const chunk_allocator = arena.allocator();
    var chunk = Chunk.init(chunk_allocator);

    var compiler = Compiler.init(source, &chunk);
    try compiler.compile();

    self.ip = 0;
    self.chunk = &chunk;
    return try self.run();
}

/// Instruction dispatcher
fn run(self: *VM) !InterpretResult {
    while (true) {
        const instruction = self.chunk.code[self.ip];

        // Debug trace
        if (config.debug_trace) {
            std.debug.print("          ", .{});
            for (self.stack[0..self.stack_top]) |elem| {
                std.debug.print("[", .{});
                elem.print();
                std.debug.print("]", .{});
            }
            std.debug.print("\n", .{});
            _ = debug.disassembleInstruction(self.chunk, self.ip);
        }

        self.ip += 1;
        const opcode: Opcode = @enumFromInt(instruction);
        switch (opcode) {
            .CONSTANT => {
                const constant = self.chunk.constants.get(self.chunk.read(self.ip));
                self.ip += 1;
                self.push(constant);
            },
            .NIL => self.push(Value{ .nil = {} }),
            .TRUE => self.push(Value{ .boolean = true }),
            .FALSE => self.push(Value{ .boolean = false }),
            .EQUAL => {
                const b = self.pop();
                const a = self.pop();
                self.push(Value{ .boolean = a.isEqual(b) });
            },
            .GREATER => try self.binaryOp('>'),
            .LESS => try self.binaryOp('<'),
            .ADD => {
                if (self.peek(0).isString() and self.peek(1).isString()) {
                    try self.concatenate(MMU.obj_allocator);
                } else if (self.peek(0).isNumber() and self.peek(1).isNumber()) {
                    const b = self.pop().number;
                    const a = self.pop().number;
                    self.push(Value{ .number = a + b });
                } else {
                    self.runtimeError("Operands must be two numbers or two strings.", .{});
                    return InterpretError.INTERPRET_RUNTIME_ERROR;
                }
            },
            .SUBTRACT => try self.binaryOp('-'),
            .MULTIPLY => try self.binaryOp('*'),
            .DIVIDE => try self.binaryOp('/'),
            .NOT => self.push(Value{ .boolean = isFalsey(self.pop()) }),
            .NEGATE => {
                if (!self.peek(0).isNumber()) {
                    self.runtimeError("Operand must be a number.", .{});
                    return InterpretError.INTERPRET_RUNTIME_ERROR;
                }
                self.push(Value{ .number = -self.pop().number });
            },
            .RETURN => {
                // Note: to be changed later
                self.pop().print();
                std.debug.print("\n", .{});

                return InterpretResult.INTERPRET_OK;
            },
            _ => continue,
        }
    }
}

inline fn binaryOp(self: *VM, comptime op: u8) !void {
    if (!self.peek(0).isNumber() or !self.peek(1).isNumber()) {
        self.runtimeError("Operands must be numbers.", .{});
        return InterpretError.INTERPRET_RUNTIME_ERROR;
    }
    const b = self.pop().number;
    const a = self.pop().number;
    switch (op) {
        '>' => self.push(Value{ .boolean = a > b }),
        '<' => self.push(Value{ .boolean = a < b }),
        '+' => self.push(Value{ .number = a + b }),
        '-' => self.push(Value{ .number = a - b }),
        '*' => self.push(Value{ .number = a * b }),
        '/' => self.push(Value{ .number = a / b }),
        else => return InterpretError.INTERPRET_RUNTIME_ERROR,
    }
}

fn isFalsey(value: Value) bool {
    // `nil` is treated as falsey here
    return value.isNil() or (value.isBool() and !value.boolean);
}

fn concatenate(self: *VM, allocator: Allocator) !void {
    const b = self.pop().obj.as(ObjString).?;
    const a = self.pop().obj.as(ObjString).?;
    const new_chars = try allocator.alloc(u8, a.chars.len + b.chars.len);
    @memcpy(new_chars[0..a.chars.len], a.chars);
    @memcpy(new_chars[a.chars.len..], b.chars);
    const new_obj = try ObjString.takeString(allocator, new_chars);
    self.push(Value{ .obj = new_obj });
}
