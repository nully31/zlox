const std = @import("std");
const Value = @import("value.zig").Value;
const Allocator = std.mem.Allocator;

/// A dynamic array structure for constants.
/// Essentially the same as `Chunk`, thus an allocator must be passed
/// when initializing via `init()` for dynamic memory allocation.
const ValueArray = @This();

count: usize = 0,
values: []Value = &.{},
allocator: Allocator,

pub fn init(allocator: Allocator) ValueArray {
    return .{ .allocator = allocator };
}

pub fn get(self: *ValueArray, index: u8) Value {
    return self.values[index];
}

pub fn write(self: *ValueArray, value: Value) !void {
    // If the current chunk doesn't have enough capacity, then grow itself by doubling the capacity.
    if (self.values.len < self.count + 1) {
        errdefer |err| {
            self.deinit();
            std.debug.print("Failed to allocate memory: {}\n", .{err});
        }
        const new_capacity = if (self.values.len < 8) 8 else self.values.len * 2;
        self.values = try self.allocator.realloc(self.values, new_capacity);
    }

    self.values[self.count] = value;
    self.count += 1;
}

pub fn deinit(self: *ValueArray) void {
    self.allocator.free(self.values);
    self.count = 0;
}

/// Prints a value read from the specified index in the pool
pub fn print(self: *ValueArray, index: u8) void {
    self.get(index).print();
}
