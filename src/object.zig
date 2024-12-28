const std = @import("std");
const VM = @import("VM.zig");
const hash_table = @import("hash_table.zig");
const Allocator = std.mem.Allocator;

/// List of `Object` type variants.
const ObjType = enum(u8) { string };

/// Object interface struct.
/// Any object implements this interface also has to have
/// an `ObjType` member with the name `tag`.
pub const Object = struct {
    type: ObjType,
    next: ?*Object,
    vtable: *const VTable = undefined,

    const VTable = struct {
        create: *const fn (self: *Object, allocator: Allocator) anyerror!*Object,
        destroy: *const fn (self: *Object, allocator: Allocator) void,
        print: *const fn (self: *Object) void,
    };

    pub fn init(comptime T: type) Object {
        return .{
            // Here an external independent enum `ObjType` needs to be used, otherwise
            // this whole struct has to be comptime which does not seem feasible.
            .type = T.tag,
            .next = null,
            .vtable = &.{
                .create = T.create,
                .destroy = T.destroy,
                .print = T.print,
            },
        };
    }

    /// Allocates self object onto heap.
    pub fn create(self: *Object, allocator: Allocator) anyerror!*Object {
        const obj = self.vtable.create(self, allocator) catch |err| return err;
        VM.MMU.register(obj);
        return obj;
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
    /// If `T` doesn't match the type of the parent object, it returns `null`.
    pub fn as(self: *Object, comptime T: type) ?*T {
        if (self.type != T.tag) return null; // cannot properly evaluate `self.type` at comptime
        // Obtain the name of `Object` field in the parent struct.
        comptime var obj_field: ?[:0]const u8 = null;
        const fields = std.meta.fields(T);
        inline for (fields) |field| {
            obj_field = switch (field.type) {
                Object => field.name,
                inline else => null,
            };
        }
        return if (obj_field) |name| @as(*T, @fieldParentPtr(name, self)) else @compileError("no 'Object' type field in the passed type.");
    }

    /// Returns true if self object is of object type `T`.
    pub fn is(self: *Object, comptime T: type) bool {
        return self.type == T.tag;
    }
};

/// A variant of `Object` type that can hold a string.
pub const ObjString = struct {
    chars: []u8,
    hash: u32 = undefined,
    obj: Object,

    const tag = ObjType.string;

    fn create(object: *Object, allocator: Allocator) anyerror!*Object {
        const self: *ObjString = @fieldParentPtr("obj", object);
        const str = try self.copyString(allocator);
        return &str.obj;
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
    /// In lox, strings are immutable so we can calculate its hash upfront
    /// and attach to the object as cache.
    fn copyString(self: ObjString, allocator: Allocator) !*ObjString {
        const hash = hash_table.hashString(self.chars);
        const ptr = try allocator.alloc(u8, self.chars.len);
        std.mem.copyForwards(u8, ptr, self.chars);
        return try allocateString(allocator, ptr, hash);
    }

    fn allocateString(allocator: Allocator, ptr: []u8, hash: u32) !*ObjString {
        const str = try allocator.create(ObjString);
        str.chars = ptr;
        str.hash = hash;
        str.obj = Object.init(ObjString);
        return str;
    }

    /// Allocates a new `ObjString` object and claims ownership of an preallocated string.
    pub fn takeString(allocator: Allocator, chars: []u8) !*Object {
        const hash = hash_table.hashString(chars);
        const str = try allocateString(allocator, chars, hash);
        VM.MMU.register(&str.obj);
        return &str.obj;
    }
};

test "string object" {
    var string = ObjString.init("test");
    const obj = try string.obj.create(VM.MMU.allocator);
    try std.testing.expect(obj.is(ObjString));
    std.debug.print("\n", .{});
    obj.print();
    std.debug.print("{s}", .{obj.as(ObjString).?.chars});
    std.debug.print("\n", .{});
    obj.destroy(VM.MMU.allocator);
}
