const std = @import("std");
const Allocator = std.mem.Allocator;

pub const ChunkErr = error{OutOfMemory};

/// Opcode enum.
pub const Opcode = enum(u8) {
    OP_RETURN,
};

/// A dynamic array structure of instructions.
pub const Chunk = struct {
    count: usize = 0,
    capacity: usize = 0,
    code: []u8 = &.{},
    allocator: Allocator,

    pub fn write(self: *Chunk, byte: u8) !void {
        // if the current chunk doesn't have enough capacity, then grow itself by doubling the capacity.
        if (self.code.len < self.count + 1) {
            const new_capacity = if (self.code.len < 8) 8 else self.code.len * 2;
            self.code = self.allocator.realloc(self.code, new_capacity) catch {
                self.allocator.free(self.code);
                return ChunkErr.OutOfMemory;
            };
        }

        self.code[self.count] = byte;
        self.count += 1;
    }

    pub fn free(self: *Chunk) void {
        self.allocator.free(self.code);
        self.count = 0;
        self.code.len = 0;
    }
};

test "writing to a chunk" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var chunk = Chunk{ .allocator = gpa.allocator() };
    defer {
        chunk.free();
        _ = gpa.deinit();
    }
    errdefer std.os.exit(1);

    comptime var i = 0;
    inline while (i < 10) : (i += 1) {
        try chunk.write('a' + i);
        try std.testing.expectEqual('a' + i, chunk.code[i]);
        if (i < 8) {
            try std.testing.expectEqual(8, chunk.code.len);
        } else {
            try std.testing.expectEqual(16, chunk.code.len);
        }
    }
}

test "sample chunk" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var chunk = Chunk{ .allocator = gpa.allocator() };
    defer {
        chunk.free();
        _ = gpa.deinit();
    }
    errdefer std.os.exit(1);

    try chunk.write(@intFromEnum(Opcode.OP_RETURN));
    const op: Opcode = @enumFromInt(chunk.code[0]);
    try std.testing.expectEqual(Opcode.OP_RETURN, op);
    chunk.free();
    std.debug.print("code: {*} {}\n", .{ chunk.code, chunk.code.len });
    try std.testing.expectEqual(0, chunk.code.len);
}
