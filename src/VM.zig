const std = @import("std");
const Chunk = @import("Chunk.zig");
const ValueArray = @import("ValueArray.zig");
const Compiler = @import("Compiler.zig");
const debug = @import("debug.zig");
const config = @import("config.zig");
const val = @import("value.zig");
const Opcode = Chunk.Opcode;
const Value = val.Value;
const ValueType = val.ValueType;

/// A stack-based virtual machine struct.
/// Use `init()` to initialize the VM instance.
const VM = @This();

pub const InterpretResult = enum { INTERPRET_OK };
pub const InterpretError = error{ INTERPRET_COMPILE_ERROR, INTERPRET_RUNTIME_ERROR };

chunk: *Chunk = undefined,
ip: usize = undefined, // The intruction pointer points at the next byte to be read
stack: [config.stack_max]Value = undefined,
stack_top: usize = undefined, // This points at the first *not-in-use* element of the stack

pub fn init() VM {
    var self = VM{};
    self.resetStack();
    return self;
}

pub fn deinit(self: *VM) void {
    self.resetStack();
}

inline fn resetStack(self: *VM) void {
    self.stack_top = 0;
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
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var chunk = Chunk.init(gpa.allocator());
    defer chunk.deinit();

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
            .ADD => try self.binaryOp('+'),
            .SUBTRACT => try self.binaryOp('-'),
            .MULTIPLY => try self.binaryOp('*'),
            .DIVIDE => try self.binaryOp('/'),
            .NOT => self.push(Value{ .boolean = isFalsey(self.pop()) }),
            .NEGATE => {
                if (!self.peek(0).is(ValueType.number)) {
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
    if (!self.peek(0).is(ValueType.number) or !self.peek(1).is(ValueType.number)) {
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
    return value.is(ValueType.nil) or (value.is(ValueType.boolean) and !value.boolean);
}
