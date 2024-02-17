const std = @import("std");
const ch = @import("chunk.zig");
const debug = @import("debug.zig");
const config = @import("config.zig");
const Chunk = ch.Chunk;
const Opcode = ch.Opcode;
const VT = @import("value.zig").T;

pub const InterpretResult = enum { INTERPRET_OK };

pub const InterpretError = error{ INTERPRET_COMPILE_ERROR, INTERPRET_RUNTIME_ERROR };

/// A stack-based virtual machine struct.
/// Use `init()` to initialize the VM instance.
pub const VM = struct {
    const Self = @This();

    chunk: *Chunk = undefined,
    ip: usize = undefined, // The intruction pointer points at the next byte to be read
    stack: [config.stack_max]VT = undefined,
    stack_top: usize = undefined, // This points at the first *not-in-use* element of the stack

    pub fn init() Self {
        var self = Self{};
        self.resetStack();
        return self;
    }

    fn resetStack(self: *Self) void {
        self.stack_top = 0;
    }

    pub fn free(self: *Self) void {
        _ = self;
    }

    pub fn push(self: *Self, value: VT) void {
        self.stack[self.stack_top] = value;
        self.stack_top += 1;
    }

    pub fn pop(self: *Self) VT {
        self.stack_top -= 1;
        return self.stack[self.stack_top];
    }

    pub fn interpret(self: *Self, source: []const u8) !InterpretResult {
        self.ip = 0;
        _ = source;
        return InterpretResult.INTERPRET_OK;
    }

    /// Instruction dispatcher
    fn run(self: *Self) !InterpretResult {
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

    fn binaryOp(self: *Self, op: Opcode) !void {
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
};
