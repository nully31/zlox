const std = @import("std");
const Chunk = @import("Chunk.zig");
const Opcode = @import("opcode.zig").Opcode;

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
    if (offset > 0 and (chunk.getLine(offset) == chunk.getLine(offset - 1))) {
        std.debug.print("{s: >4} ", .{"|"});
    } else {
        std.debug.print("{d: >4} ", .{chunk.getLine(offset)});
    }

    const instruction: u8 = chunk.read(offset);
    const opcode: Opcode = @enumFromInt(instruction);
    switch (opcode) {
        .CONSTANT => return constantInstruction(@tagName(opcode), chunk, offset),
        else => return simpleInstruction(@tagName(opcode), offset),
    }
}

fn constantInstruction(name: []const u8, chunk: *Chunk, offset: usize) usize {
    const constant = chunk.read(offset + 1);
    std.debug.print("{s: <16} {d: >4} '", .{ name, constant });
    chunk.constants.print(constant);
    std.debug.print("'\n", .{});
    return offset + 2;
}

fn simpleInstruction(name: []const u8, offset: usize) usize {
    std.debug.print("{s}\n", .{name});
    return offset + 1;
}
