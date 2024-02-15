const std = @import("std");
const Opcode = @import("chunk.zig").Opcode;
const Chunk = @import("chunk.zig").Chunk;

/// Disassembles a given chunk and prints it along with a little header.
pub fn disassembleChunk(chunk: *Chunk, name: []const u8) void {
    std.debug.print("== {s} ==\n", .{name});

    var offset: usize = 0;
    while (offset < chunk.count) {
        offset = disassembleInstruction(chunk, offset);
    }
}

/// Prints the instruction at the given offset in the bytecode.
pub fn disassembleInstruction(chunk: *Chunk, offset: usize) usize {
    std.debug.print("{d:0>4} ", .{offset});

    const instruction: u8 = chunk.code[offset];
    switch (instruction) {
        @intFromEnum(Opcode.OP_RETURN) => return simpleInstruction("OP_RETURN", offset),
        else => {
            std.debug.print("Unknown opcode {d}\n", .{instruction});
            return offset + 1;
        },
    }
}

fn simpleInstruction(name: []const u8, offset: usize) usize {
    std.debug.print("{s}\n", .{name});
    return offset + 1;
}
