const std = @import("std");
const VM = @import("VM.zig");
const Allocator = std.mem.Allocator;

pub const ObjType = enum(u8) { string };
pub const Object = union(ObjType) {
    string: *ObjString,

    /// Create an instance of the object on the heap.
    pub fn create(T: anytype) !Object {
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
            inline else => |o| o.print(),
        }
    }

    pub fn destroy(self: Object) !void {
        switch (self) {
            inline else => |o| try o.destroy(),
        }
    }
};

pub const ObjString = struct {
    chars: []u8,

    pub fn init(char: []const u8) ObjString {
        return .{ .chars = @constCast(char) };
    }

    fn copyString(self: ObjString) !*ObjString {
        const ptr = try VM.const_allocator.alloc(u8, self.chars.len);
        std.mem.copyForwards(u8, ptr, self.chars);
        return try allocateString(ptr);
    }

    fn allocateString(ptr: []u8) !*ObjString {
        const object = try VM.const_allocator.create(ObjString);
        object.*.chars = ptr;
        return object;
    }

    /// Claims ownership of an already existing string on the heap.
    pub fn takeString(chars: []u8) !*ObjString {
        return allocateString(chars);
    }

    fn print(self: *ObjString) void {
        std.debug.print("{s}", .{self.chars});
    }

    fn destroy(self: *ObjString) !void {
        _ = try VM.const_allocator.realloc(self.chars, 0);
        VM.const_allocator.destroy(self);
    }
};

test "string object" {
    const string = ObjString.init("test");
    const obj = try Object.create(string);
    try std.testing.expect(obj.is(ObjType.string));
    obj.print();
    std.debug.print("\n", .{});
    try obj.destroy();
}
