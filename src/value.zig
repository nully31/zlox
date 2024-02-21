const std = @import("std");

/// A constant's type that zlox handles.
pub const ValueType = enum { boolean, nil, number };
pub const Value = union(ValueType) {
    boolean: bool,
    nil: void,
    number: f64,

    pub fn is(self: Value, comptime T: ValueType) bool {
        return switch (self) {
            inline else => |_, tag| tag == T,
        };
    }
};

test "type check" {
    var val = Value{ .number = 123.456 };
    try std.testing.expect(val.is(ValueType.number));

    val = Value{ .boolean = false };
    try std.testing.expect(val.is(ValueType.boolean));

    val = Value{ .nil = {} };
    try std.testing.expect(val.is(ValueType.nil));
}
