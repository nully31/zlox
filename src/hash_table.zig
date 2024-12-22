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
    const max_load = 0.75;

    pub fn init(allocator: Allocator) Table {
        return .{
            .count = 0,
            .entries = &.{},
            .allocator = allocator,
        };
    }

    pub fn free(self: *Table) void {
        _ = try self.allocator.realloc(self.entries, 0); // free always succeeds
        self.* = Table.init();
    }

    /// Put a new entry into the hash table.
    /// It utilizes open addressing and linear probing as its collision resolution.
    pub fn tableSet(self: *Table, K: *ObjString, V: Value) bool {
        if (self.count + 1 > self.capacity * max_load) {
            const new_capacity = if (self.entries.len < 8) 8 else self.entries.len * 2;
            self.adjustCapacity(new_capacity);
        }
        const entry = self.findEntry(K);
        const is_new = entry.key == null;
        if (is_new) self.count += 1;
        entry.key = K;
        entry.value = V;
        return is_new;
    }

    /// Figures out which bucket the entry with the key belongs in.
    fn findEntry(self: *Table, K: *ObjString) *Entry {
        var index: u32 = K.hash % self.entries.len;
        // loop doesn't go indefinitely here since there will always be empty buckets thanks to the load factor threshold.
        while (true) : (index = (index + 1) % self.entries.len) {
            const entry = &self.entries[index];
            if (entry.key == K or entry.key == null)
                return entry;
        }
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
