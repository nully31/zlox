const std = @import("std");
const ch = @import("chunk.zig");
const debug = @import("debug.zig");
const config = @import("config.zig");
const Chunk = ch.Chunk;
const Opcode = ch.Opcode;
const VT = @import("value.zig").T;

const InterpretResult = enum {
    INTERPRET_OK,
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR,
};

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

    pub fn interpret(self: *Self, chunk: *Chunk) InterpretResult {
        self.chunk = chunk;
        self.ip = 0;
        return self.run();
    }

    /// Instruction dispatcher
    fn run(self: *Self) InterpretResult {
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
            switch (instruction) {
                @intFromEnum(Opcode.OP_CONSTANT) => {
                    const constant = self.chunk.constants.get(self.chunk.read(self.ip));
                    self.ip += 1;
                    self.push(constant);
                    std.debug.print("\n", .{});
                },
                @intFromEnum(Opcode.OP_NEGATE) => self.push(-self.pop()),
                @intFromEnum(Opcode.OP_RETURN) => {
                    // Note: to be changed later
                    std.debug.print("{d}\n", .{self.pop()});
                    return InterpretResult.INTERPRET_OK;
                },
                else => continue,
            }
        }
    }
};
