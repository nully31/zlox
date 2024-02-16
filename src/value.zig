const std = @import("std");
const Allocator = std.mem.Allocator;
const T = f64;

/// A dynamic array structure for constants.
/// Essentially the same as `Chunk`, thus an allocator must be passed
/// when initializing via `init()` for dynamic memory allocation.
pub const ValueArray = struct {
    const Self = @This();

    count: usize = 0,
    values: []T = &.{},
    allocator: Allocator,

    pub fn init(allocator: Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn write(self: *Self, value: T) !void {
        // if the current chunk doesn't have enough capacity, then grow itself by doubling the capacity.
        if (self.values.len < self.count + 1) {
            const new_capacity = if (self.values.len < 8) 8 else self.values.len * 2;
            self.values = self.allocator.realloc(self.values, new_capacity) catch |err| {
                self.allocator.free(self.values);
                return err;
            };
        }

        self.values[self.count] = value;
        self.count += 1;
    }

    pub fn free(self: *Self) void {
        self.allocator.free(self.values);
        self.count = 0;
        self.values.len = 0;
    }
};
