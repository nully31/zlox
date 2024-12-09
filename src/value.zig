const std = @import("std");
const object = @import("object.zig");
const Object = object.Object;
const ObjString = object.ObjString;

/// A constant's type that zlox handles.
pub const ValueType = enum { boolean, nil, number, obj };
pub const Value = union(ValueType) {
    boolean: bool,
    nil: void,
    number: f64,
    obj: *Object,

    /// Returns whether this value is of type `T`.
    pub fn is(self: Value, T: ValueType) bool {
        return T == std.meta.activeTag(self);
    }

    pub fn isEqual(self: Value, b: Value) bool {
        return switch (self) {
            .obj => |a| blk: {
                if (!b.is(ValueType.obj)) break :blk false;
                break :blk std.mem.eql(u8, @as(*ObjString, @ptrCast(a)).chars, @as(*ObjString, @ptrCast(b.obj)).chars);
            },
            else => std.meta.eql(self, b),
        };
    }

    pub fn print(self: Value) void {
        switch (self) {
            .boolean => |b| std.debug.print("{}", .{b}),
            .nil => std.debug.print("nil", .{}),
            .number => |n| std.debug.print("{d}", .{n}),
            .obj => |o| o.print(),
            // else => return,
        }
    }
};

test "check types" {
    var val = Value{ .number = 123.456 };
    try std.testing.expect(val.is(ValueType.number));

    val = Value{ .boolean = false };
    try std.testing.expect(val.is(ValueType.boolean));

    val = Value{ .nil = {} };
    try std.testing.expect(val.is(ValueType.nil));
}

test "compare values" {
    var a = Value{ .number = 123 };
    var b = Value{ .number = 123 };
    try std.testing.expect(a.isEqual(b));

    b = Value{ .nil = {} };
    try std.testing.expect(!a.isEqual(b));
    a = Value{ .nil = {} };
    try std.testing.expect(a.isEqual(b));
}

test "compare strings" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var string = Object{ .string = ObjString{ .allocator = allocator, .init_chars = "test" } };
    const string1 = try string.allocate();
    const a = Value{ .obj = string1 };
    var b = a;
    try std.testing.expect(a.isEqual(b));

    string = Object{ .string = ObjString{ .allocator = allocator, .init_chars = "test2" } };
    const string2 = try string.allocate();
    b = Value{ .obj = string2 };
    try std.testing.expect(!a.isEqual(b));

    b = Value{ .boolean = false };
    try std.testing.expect(!a.isEqual(b));
}
