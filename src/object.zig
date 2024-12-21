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
        create: *const fn (self: *Object, allocator: Allocator) Allocator.Error!*Object,
        destroy: *const fn (self: *Object, allocator: Allocator) void,
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
    pub fn create(self: *Object, allocator: Allocator) Allocator.Error!*Object {
        return try self.vtable.create(self, allocator);
    }

    /// Free self object.
    pub fn destroy(self: *Object, allocator: Allocator) void {
        return self.vtable.destroy(self, allocator);
    }

    /// Should be pretty much self explanatory.
    pub fn print(self: *Object) void {
        return self.vtable.print(self);
    }

    /// Returns a pointer to the parent struct of type `T`.
    /// If `T` doesn't have any `Object` field (which it should), it throws a compile error.
    pub fn as(self: *Object, comptime T: type) *T {
        comptime var obj_field: ?[:0]const u8 = null;
        const info = std.meta.fields(T);
        inline for (info) |field| {
            obj_field = switch (field.type) {
                Object => field.name,
                inline else => null,
            };
        }
        return if (obj_field) |name| @as(*T, @fieldParentPtr(name, self)) else @compileError("no 'Object' type field in the passed type.");
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

    fn create(object: *Object, allocator: Allocator) Allocator.Error!*Object {
        const self: *ObjString = @fieldParentPtr("obj", object);
        const t = try self.copyString(allocator);
        return &t.obj;
    }

    fn destroy(object: *Object, allocator: Allocator) void {
        const self: *ObjString = @fieldParentPtr("obj", object);
        _ = allocator.realloc(self.chars, 0) catch unreachable; // free always succeeds
        allocator.destroy(self);
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

    /// Allocates the attached string onto heap, then allocates the object itself.
    /// Uses the same allocator for allocating both.
    fn copyString(self: ObjString, allocator: Allocator) !*ObjString {
        const ptr = try allocator.alloc(u8, self.chars.len);
        std.mem.copyForwards(u8, ptr, self.chars);
        return try allocateString(allocator, ptr);
    }

    fn allocateString(allocator: Allocator, ptr: []u8) !*ObjString {
        const object = try allocator.create(ObjString);
        object.chars = ptr;
        object.obj = Object.init(ObjString);
        return object;
    }

    /// Claims ownership of an already allocated string.
    pub fn takeString(allocator: Allocator, chars: []u8) !*ObjString {
        return allocateString(allocator, chars);
    }
};

test "string object" {
    var string = ObjString.init("test");
    var obj = try string.obj.create(VM.const_allocator);
    try std.testing.expect(obj.is(ObjType.string));
    std.debug.print("\n", .{});
    obj.print();
    std.debug.print("{s}", .{obj.as(ObjString).chars});
    std.debug.print("\n", .{});
    obj.destroy(VM.const_allocator);
}
