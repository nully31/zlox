const std = @import("std");
const ValueArray = @import("ValueArray.zig");
const Value = @import("value.zig").Value;
const Allocator = std.mem.Allocator;

/// A dynamic array structure for instructions.
/// An allocator must be passed when initializing via `init()` for dynamic memory allocation.
/// The same allocator is also used for initializing the `constants` member.
const Chunk = @This();

/// Opcode enum.
pub const Opcode = enum(u8) {
    CONSTANT,
    NIL,
    TRUE,
    FALSE,
    EQUAL, // a != b can be written as !(a == b), thus no opcode for `!=`
    GREATER, // a <= b <-> !(a > b)
    LESS, // a >= b <-> !(a < b)
    ADD,
    SUBTRACT,
    MULTIPLY,
    DIVIDE,
    NOT,
    NEGATE,
    RETURN,
    _,

    /// Returns a byte which represents the current opcode.
    pub fn toByte(self: Opcode) u8 {
        return @intFromEnum(self);
    }

    /// Returns an opcode literal equivalent to the given `byte`.
    pub fn toOpcode(byte: u8) Opcode {
        return @enumFromInt(byte);
    }
};

count: usize = 0,
code: []u8 = &.{},
lines: []usize = &.{}, // Indicates which lines the instructions occur in the source code
constants: ValueArray = undefined, // Constant pool
allocator: Allocator,

pub fn init(allocator: Allocator) Chunk {
    var chunk = Chunk{ .allocator = allocator };
    chunk.constants = ValueArray.init(allocator);
    return chunk;
}

pub fn read(self: *Chunk, address: usize) u8 {
    return self.code[address];
}

pub fn getLine(self: *Chunk, address: usize) usize {
    return self.lines[address];
}

pub fn write(self: *Chunk, byte: u8, line: usize) !void {
    // If the current chunk doesn't have enough capacity, then grow itself by doubling the capacity.
    // Indices of `code` and `lines` are tied together so they always have the same sizes.
    if (self.code.len < self.count + 1) {
        errdefer |err| {
            self.deinit();
            std.debug.print("Failed to allocate memory: {}", .{err});
        }
        const new_capacity = if (self.code.len < 8) 8 else self.code.len * 2;
        self.code = try self.allocator.realloc(self.code, new_capacity);
        self.lines = try self.allocator.realloc(self.lines, new_capacity);
    }

    self.code[self.count] = byte;
    self.lines[self.count] = line;
    self.count += 1;
}

pub fn addConstant(self: *Chunk, value: Value) !usize {
    try self.constants.write(value);
    return self.constants.count - 1;
}

pub fn deinit(self: *Chunk) void {
    self.constants.deinit();
    self.allocator.free(self.code);
    self.allocator.free(self.lines);
    self.count = 0;
}

test "write to a chunk" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var chunk = Chunk.init(allocator);
    defer {
        chunk.deinit();
        _ = gpa.deinit();
    }

    comptime var i = 0;
    inline while (i < 10) : (i += 1) {
        try chunk.write(Opcode.RETURN.toByte(), 123);
        const op = Opcode.toOpcode(chunk.code[i]);
        try std.testing.expectEqual(Opcode.RETURN, op);
        if (i < 8) {
            try std.testing.expectEqual(8, chunk.code.len);
        } else {
            try std.testing.expectEqual(16, chunk.code.len);
        }
    }
}
