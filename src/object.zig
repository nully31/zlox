const std = @import("std");
const Allocator = std.mem.Allocator;

pub const ObjType = enum(u8) { string };
pub const Object = union(ObjType) {
    string: *ObjString,

    pub fn allocate(T: anytype) !Object {
        switch (@TypeOf(T)) {
            ObjString => return Object{ .string = try T.copyString() },
            else => unreachable,
        }
    }

    pub fn isObjType(self: Object, T: ObjType) bool {
        return T == std.meta.activeTag(self);
    }

    pub fn print(self: Object) void {
        switch (self) {
            inline else => |obj| obj.print(),
        }
    }
};

pub const ObjString = struct {
    allocator: Allocator,
    init_chars: []const u8,
    chars: []u8 = undefined, // For heap allocation

    fn copyString(self: ObjString) !*ObjString {
        const ptr = try self.allocator.alloc(u8, self.init_chars.len);
        std.mem.copyForwards(u8, ptr, self.init_chars);
        return try allocateString(self.allocator, ptr);
    }

    fn allocateString(allocator: Allocator, ptr: []u8) !*ObjString {
        const object = try allocator.create(ObjString);
        object.*.chars = ptr;
        return object;
    }

    pub fn takeString(allocator: Allocator, chars: []u8) !*ObjString {
        return allocateString(allocator, chars);
    }

    fn print(self: ObjString) void {
        std.debug.print("{s}", .{self.chars});
    }
};

test "string object" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const string = ObjString{ .allocator = allocator, .init_chars = "test" };
    const obj = try Object.allocate(string);
    try std.testing.expect(obj.isObjType(ObjType.string));
    obj.print();
    std.debug.print("\n", .{});
}
