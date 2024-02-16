const std = @import("std");
const ch = @import("chunk.zig");
const debug = @import("debug.zig");
const config = @import("config.zig");
const Chunk = ch.Chunk;
const Opcode = ch.Opcode;

const InterpretResult = enum {
    INTERPRET_OK,
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR,
};

pub const VM = struct {
    const Self = @This();

    chunk: *Chunk = undefined,
    ip: usize = undefined,

    pub fn init() Self {
        return Self{};
    }

    pub fn free(self: *Self) void {
        _ = self;
    }

    pub fn interpret(self: *Self, chunk: *Chunk) InterpretResult {
        self.chunk = chunk;
        self.ip = 0;
        return self.run();
    }

    fn run(self: *Self) InterpretResult {
        while (true) {
            const instruction = self.chunk.code[self.ip];
            if (config.debug_trace) {
                _ = debug.disassembleInstruction(self.chunk, self.ip);
            }
            self.ip += 1;
            switch (instruction) {
                @intFromEnum(Opcode.OP_CONSTANT) => {
                    // FIXME: for now, it just prints out the constant
                    self.chunk.constants.print(self.chunk.code[self.ip]);
                    self.ip += 1;
                    std.debug.print("\n", .{});
                },
                @intFromEnum(Opcode.OP_RETURN) => return InterpretResult.INTERPRET_OK,
                else => continue,
            }
        }
    }
};
