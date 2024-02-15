const std = @import("std");
const Allocator = std.mem.Allocator;

pub const ChunkErr = error{AllocFail};

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
            self.capacity = if (self.code.len < 8) 8 else self.code.len * 2;
            self.code = self.allocator.realloc(self.code, self.capacity) catch {
                self.allocator.free(self.code);
                return ChunkErr.AllocFail;
            };
        }

        self.code[self.count] = byte;
        self.count += 1;
    }

    pub fn free(self: *Chunk) void {
        self.allocator.free(self.code);
        self.count = 0;
        self.capacity = 0;
    }
};

test "writing to a chunk" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    errdefer std.os.exit(1);
    var chunk = Chunk{ .allocator = gpa.allocator() };
    comptime var i = 0;
    inline while (i < 10) : (i += 1) {
        try chunk.write('a' + i);
        try std.testing.expectEqual(chunk.code[i], 'a' + i);
        if (i < 8) {
            try std.testing.expectEqual(chunk.code.len, 8);
        } else {
            try std.testing.expectEqual(chunk.code.len, 16);
        }
        try std.testing.expectEqual(chunk.code.len, chunk.capacity);
    }
}

test "sample chunk" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    errdefer std.os.exit(1);
    var chunk = Chunk{ .allocator = gpa.allocator() };
    try chunk.write(@intFromEnum(Opcode.OP_RETURN));
    const op: Opcode = @enumFromInt(chunk.code[0]);
    try std.testing.expectEqual(Opcode.OP_RETURN, op);
    chunk.free();
    std.debug.print("code: {*} {}\n", .{ chunk.code, chunk.code.len });
    try std.testing.expectEqual(chunk.capacity, 0);
}
