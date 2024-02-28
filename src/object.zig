const std = @import("std");
const Allocator = std.mem.Allocator;

pub const ObjType = enum { string };
pub const Object = union(ObjType) {
    string: String,

    pub fn is(self: Object, T: ObjType) bool {
        return switch (self) {
            inline else => |_, tag| tag == T,
        };
    }
};

pub const String = struct {
    allocator: Allocator,
    chars: []u8 = undefined, // For heap allocation

    pub fn new(allocator: Allocator) String {
        return .{ .allocator = allocator };
    }
};
