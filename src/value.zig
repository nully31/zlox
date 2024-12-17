const std = @import("std");
const object = @import("object.zig");
const Object = object.Object;
const ObjString = object.ObjString;
const ObjType = object.ObjType;

/// A constant's type that zlox handles.
pub const ValueType = enum(u8) { boolean, nil, number, obj };
pub const Value = union(ValueType) {
    boolean: bool,
    nil: void,
    number: f64,
    obj: Object,

    /// Returns whether this value is of type `T`.
    inline fn is(self: Value, comptime T: ValueType) bool {
        return T == std.meta.activeTag(self);
    }

    pub fn isBool(self: Value) bool {
        return self.is(ValueType.boolean);
    }

    pub fn isNil(self: Value) bool {
        return self.is(ValueType.nil);
    }

    pub fn isNumber(self: Value) bool {
        return self.is(ValueType.number);
    }

    pub fn isString(self: Value) bool {
        if (!self.is(ValueType.obj)) return false;
        return self.obj.is(ObjType.string);
    }

    pub fn isEqual(self: Value, b: Value) bool {
        return switch (self) {
            .obj => |a| blk: {
                if (!self.isString() or !b.isString()) break :blk false;
                break :blk std.mem.eql(u8, a.string.chars, b.obj.string.chars);
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
    var val: Value = .{ .number = 123.456 };
    try std.testing.expect(val.isNumber());

    val = Value{ .boolean = false };
    try std.testing.expect(val.isBool());

    val = Value{ .nil = {} };
    try std.testing.expect(val.isNil());
}

test "compare values" {
    var a: Value = .{ .number = 123 };
    var b: Value = .{ .number = 123 };
    try std.testing.expect(a.isEqual(b));

    b = Value{ .nil = {} };
    try std.testing.expect(!a.isEqual(b));
    a = Value{ .nil = {} };
    try std.testing.expect(a.isEqual(b));
}

test "compare strings" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var string = ObjString.init("test1");
    const a: Value = .{ .obj = try Object.create(string, allocator) };
    var b = a;
    try std.testing.expect(a.isEqual(b));

    string = ObjString.init("test2");
    b = Value{ .obj = try Object.create(string, allocator) };
    try std.testing.expect(!a.isEqual(b));

    b = Value{ .boolean = false };
    try std.testing.expect(!a.isEqual(b));
}
