const std = @import("std");
const Allocator = std.mem.Allocator;

pub const ObjType = enum(u8) { string };
pub const Object = union(ObjType) {
    string: ObjString,

    pub fn allocate(self: Object) !*Object {
        switch (self) {
            .string => |str| return @ptrCast(try str.copyString()),
            // inline else => |obj| return obj.allocateObj(self.allocator),
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
    allocator: Allocator,
    init_chars: []const u8,
    chars: []u8 = undefined, // For heap allocation

    fn copyString(self: ObjString) !*ObjString {
        const ptr = try self.allocator.alloc(u8, self.init_chars.len);
        std.mem.copyForwards(u8, ptr, self.init_chars);
        return try self.allocateString(ptr);
    }

    fn allocateString(self: ObjString, ptr: []u8) !*ObjString {
        const object = try self.allocator.create(ObjString);
        object.*.chars = ptr;
        return object;
    }

    fn print(self: ObjString) void {
        std.debug.print("{s}", .{self.chars});
    }
};

test "string object" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var string = Object{ .string = ObjString{ .allocator = allocator, .init_chars = "test" } };
    const obj = try string.allocate();
    try std.testing.expect(string.is(ObjType.string));
    @as(*ObjString, @ptrCast(obj)).print();
    std.debug.print("\n", .{});
}
