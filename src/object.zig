const std = @import("std");
const VM = @import("VM.zig");
const Allocator = std.mem.Allocator;

/// List of `Object` type variants.
pub const ObjType = enum(u8) { string };

/// Object interface struct.
pub const Object = struct {
    type: ObjType,
    vtable: *const VTable = undefined,

    const VTable = struct {
        create: *const fn (self: *Object) Allocator.Error!*Object,
        destroy: *const fn (self: *Object) void,
        print: *const fn (self: *Object) void,
    };

    pub fn init(comptime T: type) Object {
        return .{
            .type = T.obj_type,
            .vtable = &.{
                .create = T.create,
                .destroy = T.destroy,
                .print = T.print,
            },
        };
    }

    /// Allocates self object onto heap.
    pub fn create(self: *Object) Allocator.Error!*Object {
        return try self.vtable.create(self);
    }

    /// Free self object.
    pub fn destroy(self: *Object) void {
        return self.vtable.destroy(self);
    }

    pub fn print(self: *Object) void {
        return self.vtable.print(self);
    }

    pub fn is(self: *Object, V: ObjType) bool {
        return self.type == V;
    }
};

/// A variant of `Object` type that can hold a string.
pub const ObjString = struct {
    chars: []u8,
    obj: Object,

    const obj_type = ObjType.string;

    fn create(object: *Object) Allocator.Error!*Object {
        const self: *ObjString = @fieldParentPtr("obj", object);
        const t = try self.copyString();
        return &t.obj;
    }

    fn destroy(object: *Object) void {
        const self: *ObjString = @fieldParentPtr("obj", object);
        _ = VM.const_allocator.realloc(self.chars, 0) catch unreachable; // free always succeeds
        VM.const_allocator.destroy(self);
    }

    fn print(object: *Object) void {
        const self: *ObjString = @fieldParentPtr("obj", object);
        std.debug.print("{s}", .{self.chars});
    }

    pub fn init(char: []const u8) ObjString {
        return .{
            .chars = @constCast(char),
            .obj = Object.init(ObjString),
        };
    }

    fn copyString(self: ObjString) !*ObjString {
        const ptr = try VM.const_allocator.alloc(u8, self.chars.len);
        std.mem.copyForwards(u8, ptr, self.chars);
        return try allocateString(ptr);
    }

    fn allocateString(ptr: []u8) !*ObjString {
        const object = try VM.const_allocator.create(ObjString);
        object.chars = ptr;
        object.obj = Object.init(ObjString);
        return object;
    }

    /// Claims ownership of an already existing string on the heap.
    pub fn takeString(chars: []u8) !*ObjString {
        return allocateString(chars);
    }
};

test "string object" {
    var string = ObjString.init("test");
    var obj = try string.obj.create();
    try std.testing.expect(obj.is(ObjType.string));
    std.debug.print("\n", .{});
    obj.print();
    std.debug.print("\n", .{});
    obj.destroy();
}
