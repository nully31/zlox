const std = @import("std");
const Opcode = @import("chunk.zig").Opcode;
const Chunk = @import("chunk.zig").Chunk;
const ValueArray = @import("value.zig").ValueArray;
const debug = @import("debug.zig");

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // don't forget to flush!
}

test "simple chunk" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var chunk = Chunk{ .allocator = allocator, .constants = ValueArray{ .allocator = allocator } };
    defer {
        chunk.free();
        _ = gpa.deinit();
    }
    errdefer std.os.exit(1);

    try chunk.write(@intFromEnum(Opcode.OP_RETURN));
    debug.disassembleChunk(&chunk, "test chunk");
}
