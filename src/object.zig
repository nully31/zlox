const std = @import("std");
const VM = @import("VM.zig");
const Allocator = std.mem.Allocator;

pub const ObjType = enum { string };

pub const Object = struct {
    type: ObjType,
    createFn: *const fn (self: *Object) Allocator.Error!*Object,
    destroyFn: *const fn (self: *Object) void,
    printFn: *const fn (self: *Object) void,

    pub fn create(self: *Object) Allocator.Error!*Object {
        return try self.createFn(self);
    }

    pub fn destroy(self: *Object) void {
        return self.destroyFn(self);
    }

    pub fn print(self: *Object) void {
        return self.printFn(self);
    }

    pub fn is(self: *Object, V: ObjType) bool {
        return self.type == V;
    }
};

pub const ObjString = struct {
    obj: Object = .{
        .type = ObjType.string,
        .createFn = create,
        .destroyFn = destroy,
        .printFn = print,
    },
    chars: []u8,

    fn create(object: *Object) Allocator.Error!*Object {
        const self: *ObjString = @fieldParentPtr("obj", object);
        const t = try self.copyString();
        return &t.obj;
    }

    fn destroy(object: *Object) void {
        const self: *ObjString = @fieldParentPtr("obj", object);
        _ = VM.const_allocator.realloc(self.chars, 0) catch unreachable; // freeing always succeeds
        VM.const_allocator.destroy(self);
    }

    fn print(object: *Object) void {
        const self: *ObjString = @fieldParentPtr("obj", object);
        std.debug.print("{s}", .{self.chars});
    }

    pub fn init(char: []const u8) ObjString {
        return .{ .chars = @constCast(char) };
    }

    fn copyString(self: ObjString) !*ObjString {
        const ptr = try VM.const_allocator.alloc(u8, self.chars.len);
        std.mem.copyForwards(u8, ptr, self.chars);
        const s_obj = try allocateString(ptr);
        s_obj.obj = self.obj;
        return s_obj;
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
};

test "string object" {
    var string = ObjString.init("test");
    var obj = try string.obj.create();
    try std.testing.expect(obj.is(ObjType.string));
    obj.print();
    std.debug.print("\n", .{});
    obj.destroy();
}
