const std = @import("std");
const Allocator = std.mem.Allocator;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

/// Opcode enum.
pub const Opcode = enum {
    OP_RETURN,
};

/// A dynamic array structure of instructions.
pub const Chunk = struct {
    count: usize = 0,
    capacity: usize = 0,
    code: []u8 = &.{},
    allocator: Allocator = gpa.allocator(),

    pub fn write(self: *Chunk, byte: u8) void {
        // if the current chunk doesn't have enough capacity, then grow itself by doubling the capacity.
        if (self.code.len < self.count + 1) {
            self.capacity = if (self.code.len < 8) 8 else self.code.len * 2;
            self.code = self.allocator.realloc(self.code, self.capacity) catch {
                self.allocator.free(self.code);
                std.os.exit(1);
            };
        }

        self.code[self.count] = byte;
        self.count += 1;
    }
};

test "writing to a chunk" {
    var chunk = Chunk{};
    chunk.write('a');
    chunk.write('b');
    chunk.write('!');
    try std.testing.expectEqual(chunk.code[0], 'a');
    try std.testing.expectEqual(chunk.code[1], 'b');
    try std.testing.expectEqual(chunk.code[2], '!');
    try std.testing.expectEqual(chunk.code.len, 8);
}
