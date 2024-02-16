const std = @import("std");
const ch = @import("chunk.zig");
const val = @import("value.zig");
const debug = @import("debug.zig");
const Chunk = ch.Chunk;
const Opcode = ch.Opcode;

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
    var chunk = Chunk.init(allocator);
    defer {
        chunk.free();
        _ = gpa.deinit();
    }
    errdefer std.os.exit(1);

    try chunk.write(@intFromEnum(Opcode.OP_CONSTANT), 123);
    const constant = try chunk.addConstant(1.2);
    try chunk.write(constant, 123);

    try chunk.write(@intFromEnum(Opcode.OP_RETURN), 123);
    debug.disassembleChunk(&chunk, "test chunk");
}
