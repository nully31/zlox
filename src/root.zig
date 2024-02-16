const std = @import("std");
const testing = std.testing;
const ch = @import("chunk.zig");
const val = @import("value.zig");
const debug = @import("debug.zig");
const VM = @import("vm.zig").VM;
const Chunk = ch.Chunk;
const Opcode = ch.Opcode;

test "writing to a chunk" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var chunk = Chunk.init(allocator);
    defer {
        chunk.free();
        _ = gpa.deinit();
    }
    errdefer std.os.exit(1);

    comptime var i = 0;
    inline while (i < 10) : (i += 1) {
        try chunk.write(@intFromEnum(Opcode.OP_RETURN), 123);
        const op: Opcode = @enumFromInt(chunk.code[i]);
        try std.testing.expectEqual(Opcode.OP_RETURN, op);
        if (i < 8) {
            try std.testing.expectEqual(8, chunk.code.len);
        } else {
            try std.testing.expectEqual(16, chunk.code.len);
        }
    }
}
