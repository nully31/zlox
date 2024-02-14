const std = @import("std");
const Allocator = std.mem.Allocator;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub const Opcode = enum {
    OP_RETURN,
};

pub const Chunk = struct {
    count: u32 = 0,
    capacity: u32 = 0,
    code: ?*u8 = null,
    allocator: Allocator = gpa.allocator(),

    pub fn write(self: *Chunk, byte: u8) void {
        // if the current chunk doesn't have enough capacity, then grow itself by doubling the capacity.
        if (self.capacity < self.count + 1) {
            const old_capacity = self.capacity;
            self.capacity = if (self.capacity < 8) 8 else self.capacity * 2;
            self.code = self.allocator.realloc(self.code, self.capacity) catch {
                self.allocator.destroy(self.code);
                std.os.exit(1);
            };
        }
    }
};
