const std = @import("std");
const object = @import("object.zig");
const value = @import("value.zig");
const Allocator = std.mem.Allocator;
const ObjString = object.ObjString;
const Value = value.Value;

pub const Entry = struct {
    key: ?*ObjString,
    value: Value,
};

pub const Table = struct {
    count: usize,
    entries: []Entry,
    allocator: Allocator,

    /// Table's load factor threshold to increase the capacity.
    const max_load: f64 = 0.75;

    pub fn init(allocator: Allocator) Table {
        return .{
            .count = 0,
            .entries = &.{},
            .allocator = allocator,
        };
    }

    pub fn destroy(self: *Table) void {
        _ = self.allocator.realloc(self.entries, 0) catch unreachable; // free always succeeds
        self.* = Table.init(self.allocator);
    }

    /// Retrieve value corresponding to the given key.
    /// Returns null if the key doesn't exist in the table.
    pub fn get(self: *Table, K: *ObjString) ?Value {
        if (self.count == 0) return null;
        const entry = self.findEntry(K);
        if (entry.key) |_| return entry.value else null;
    }

    /// Put a new entry into the hash table.
    /// It utilizes open addressing and linear probing as its collision resolution.
    pub fn set(self: *Table, K: *ObjString, V: Value) !bool {
        if (@as(f64, @floatFromInt(self.count + 1)) > @as(f64, @floatFromInt(self.entries.len)) * max_load) {
            const new_capacity = if (self.entries.len < 8) 8 else self.entries.len * 2;
            try self.adjustCapacity(new_capacity);
        }
        const entry = self.findEntry(K);
        const is_new = entry.key == null;
        if (is_new) self.count += 1;
        entry.key = K;
        entry.value = V;
        return is_new;
    }

    /// Delete an entry.
    pub fn delete(self: *Table, K: *ObjString) bool {
        if (self.count == 0) return false;
        const entry = self.findEntry(K);
        if (entry.key) |_| {
            // place a tombston in the entry.
            entry.key = null;
            entry.value = .{ .boolean = true };
            return true;
        } else return false;
    }

    /// Copy all the content of a table to another.
    pub fn addAll(from: *Table, to: *Table) !void {
        for (from.entries) |*entry| {
            if (entry.key) |k| _ = try to.tableSet(k, entry.value);
        }
    }

    /// Figure out which bucket the entry with the key belongs in.
    fn findEntry(self: *Table, K: *ObjString) *Entry {
        var index: usize = K.hash % self.entries.len;
        var tombstone: ?*Entry = null;
        // loop here doesn't go indefinitely since there will always be empty buckets thanks to the load factor threshold.
        while (true) : (index = (index + 1) % self.entries.len) {
            const entry = &self.entries[index];
            if (entry.key) |k| {
                // found the entry.
                if (K == k) return entry;
            } else {
                if (entry.value.isNil()) {
                    // empty entry.
                    return if (tombstone) |t| t else entry;
                } else {
                    // found a tombstone.
                    if (tombstone == null) tombstone = entry;
                }
            }
        }
    }

    /// Reconstruct the hash table after resizing as entries depends on array size for their buckets.
    fn adjustCapacity(self: *Table, capacity: usize) !void {
        const entries: []Entry = try self.allocator.realloc(self.entries, capacity);
        // initialize the new table.
        for (entries) |*entry| {
            entry.*.key = null;
            entry.*.value = .{ .nil = {} };
        }
        // re-insert every entry to the new table.
        for (self.entries) |*entry| {
            if (entry.key) |k| {
                const dest = self.findEntry(k);
                dest.key = entry.key;
                dest.value = entry.value;
            }
        }
        _ = self.allocator.realloc(self.entries, 0) catch unreachable; // free always suceeds
        self.entries = entries;
    }
};

/// Compute a hash of `key` using the *FNV-1a* algorithm.
/// You may get the same result as if `std.array_hash_map.hashString()`
/// used `std.hash.Fnv1a_32`.
pub fn hashString(key: []const u8) u32 {
    var hash: u32 = 0x811c9dc5;
    for (key) |byte| {
        hash ^= byte;
        hash = @mulWithOverflow(hash, 0x01000193)[0];
    }
    return hash;
}

test "test hash" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var string = ObjString.init("test");
    var obj = try string.obj.create(allocator);
    var map = Table.init(allocator);
    _ = try map.set(obj.as(ObjString).?, .{ .boolean = true });
    const e = map.findEntry(obj.as(ObjString).?);
    std.debug.print("\n", .{});
    e.key.?.obj.print();
    std.debug.print("\n", .{});
    e.value.print();
    std.debug.print("\n", .{});
    try std.testing.expect(map.delete(e.key.?));
    map.destroy();
    obj.destroy(allocator);
}
