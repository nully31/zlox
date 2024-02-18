const std = @import("std");
const Chunk = @import("Chunk.zig");
const ValueArray = @import("ValueArray.zig");
const debug = @import("debug.zig");
const config = @import("config.zig");
const Opcode = Chunk.Opcode;

/// A stack-based virtual machine struct.
/// Use `init()` to initialize the VM instance.
const VM = @This();

pub const InterpretResult = enum { INTERPRET_OK };
pub const InterpretError = error{ INTERPRET_COMPILE_ERROR, INTERPRET_RUNTIME_ERROR };

chunk: *Chunk = undefined,
ip: usize = undefined, // The intruction pointer points at the next byte to be read
stack: [config.stack_max]ValueArray.T = undefined,
stack_top: usize = undefined, // This points at the first *not-in-use* element of the stack

pub fn init() VM {
    var self = VM{};
    self.resetStack();
    return self;
}

pub fn free(self: *VM) void {
    self.resetStack();
}

fn resetStack(self: *VM) void {
    self.stack_top = 0;
}

pub fn push(self: *VM, value: ValueArray.T) void {
    self.stack[self.stack_top] = value;
    self.stack_top += 1;
}

pub fn pop(self: *VM) ValueArray.T {
    self.stack_top -= 1;
    return self.stack[self.stack_top];
}

pub fn interpret(self: *VM, source: []const u8) !InterpretResult {
    self.ip = 0;
    _ = source;
    return InterpretResult.INTERPRET_OK;
}

/// Instruction dispatcher
fn run(self: *VM) !InterpretResult {
    while (true) {
        const instruction = self.chunk.code[self.ip];
        if (config.debug_trace) {
            std.debug.print("          ", .{});
            for (self.stack[0..self.stack_top]) |elem| {
                std.debug.print("[{d: ^7}]", .{elem});
            }
            std.debug.print("\n", .{});
            _ = debug.disassembleInstruction(self.chunk, self.ip);
        }
        self.ip += 1;
        const opcode: Opcode = @enumFromInt(instruction);
        switch (opcode) {
            .OP_CONSTANT => {
                const constant = self.chunk.constants.get(self.chunk.read(self.ip));
                self.ip += 1;
                self.push(constant);
            },
            .OP_ADD => try self.binaryOp('+'),
            .OP_SUBTRACT => try self.binaryOp('-'),
            .OP_MULTIPLY => try self.binaryOp('*'),
            .OP_DIVIDE => try self.binaryOp('/'),
            .OP_NEGATE => try self.push(-self.pop()),
            .OP_RETURN => {
                // Note: to be changed later
                std.debug.print("{d}\n", .{self.pop()});
                return InterpretResult.INTERPRET_OK;
            },
            _ => continue,
        }
    }
}

inline fn binaryOp(self: *VM, op: Opcode) !void {
    const b = self.pop();
    const a = self.pop();
    switch (op) {
        '+' => self.push(a + b),
        '-' => self.push(a - b),
        '*' => self.push(a * b),
        '/' => self.push(a / b),
        else => return InterpretError.INTERPRET_RUNTIME_ERROR,
    }
}
