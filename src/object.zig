const std = @import("std");

pub const ObjectType = enum { string };
pub const Object = struct {
    type: ObjectType,
};
