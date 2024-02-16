const std = @import("std");
const val = @import("value.zig");
const Allocator = std.mem.Allocator;
const ValueArray = val.ValueArray;
const VT = val.T;

/// Opcode enum.
pub const Opcode = enum(u8) {
    OP_CONSTANT,
    OP_RETURN,
};

/// A dynamic array structure for instructions.
/// An allocator must be passed when initializing via `init()` for dynamic memory allocation.
/// The same allocator is also used for initializing the `constants` member.
pub const Chunk = struct {
    const Self = @This();

    count: usize = 0,
    code: []u8 = &.{},
    lines: []usize = &.{}, // Indicates which lines the instructions occur in the source code
    constants: ValueArray = undefined, // Constant pool
    allocator: Allocator,

    pub fn init(allocator: Allocator) Self {
        var chunk = Self{ .allocator = allocator };
        chunk.constants = ValueArray.init(allocator);
        return chunk;
    }

    pub fn read(self: *Self, address: usize) u8 {
        return self.code[address];
    }

    pub fn getLine(self: *Self, address: usize) usize {
        return self.lines[address];
    }

    pub fn write(self: *Self, byte: u8, line: usize) !void {
        // If the current chunk doesn't have enough capacity, then grow itself by doubling the capacity.
        if (self.code.len < self.count + 1) {
            const new_capacity = if (self.code.len < 8) 8 else self.code.len * 2;
            self.code = self.allocator.realloc(self.code, new_capacity) catch |err| {
                self.allocator.free(self.code);
                return err;
            };
            self.lines = self.allocator.realloc(self.lines, new_capacity) catch |err| {
                self.allocator.free(self.lines);
                return err;
            };
        }

        self.code[self.count] = byte;
        self.lines[self.count] = line;
        self.count += 1;
    }

    pub fn addConstant(self: *Self, value: VT) !u8 {
        try self.constants.write(value);
        return self.constants.count - 1;
    }

    pub fn free(self: *Self) void {
        self.constants.free();
        self.allocator.free(self.code);
        self.allocator.free(self.lines);
        self.count = 0;
    }
};
