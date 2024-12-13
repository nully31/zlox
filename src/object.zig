const std = @import("std");
const Allocator = std.mem.Allocator;
const allocator = @import("VM.zig").const_allocator;

pub const ObjType = enum(u8) { string };
pub const Object = union(ObjType) {
    string: *ObjString,

    pub fn allocate(T: anytype) !Object {
        switch (@TypeOf(T)) {
            ObjString => return Object{ .string = try T.copyString() },
            else => unreachable,
        }
    }

    pub fn is(self: Object, T: ObjType) bool {
        return T == std.meta.activeTag(self);
    }

    pub fn print(self: Object) void {
        switch (self) {
            inline else => |obj| obj.print(),
        }
    }
};

pub const ObjString = struct {
    chars: []u8,

    pub fn init(char: []const u8) ObjString {
        return .{ .chars = @constCast(char) };
    }

    fn copyString(self: ObjString) !*ObjString {
        const ptr = try allocator.alloc(u8, self.chars.len);
        std.mem.copyForwards(u8, ptr, self.chars);
        return try allocateString(ptr);
    }

    fn allocateString(ptr: []u8) !*ObjString {
        const object = try allocator.create(ObjString);
        object.*.chars = ptr;
        return object;
    }

    pub fn takeString(chars: []u8) !*ObjString {
        return allocateString(chars);
    }

    fn print(self: ObjString) void {
        std.debug.print("{s}", .{self.chars});
    }
};

test "string object" {
    const string = ObjString.init("test");
    const obj = try Object.allocate(string);
    try std.testing.expect(obj.is(ObjType.string));
    obj.print();
    std.debug.print("\n", .{});
}
