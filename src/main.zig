const std = @import("std");
const Chunk = @import("Chunk.zig");
const ValueArray = @import("ValueArray.zig");
const VM = @import("VM.zig");
const debug = @import("debug.zig");
const Allocator = std.mem.Allocator;
const Opcode = Chunk.Opcode;

const MainError = error{argsTooMany};

pub fn main() !void {
    var buffer: [1024 * 1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    // Parse args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var vm = VM.init();
    defer vm.deinit();

    if (args.len == 1) {
        try vm.repl();
    } else if (args.len == 2) {
        try vm.runFile(args[1], allocator);
    } else {
        std.debug.print("Usage: zlox [path]\n", .{});
        std.debug.print("If no [path] is provided, zlox starts in interactive mode.\n", .{});
        return MainError.argsTooMany;
    }
}

test "simple chunk" {
    const Value = @import("value.zig").Value;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var chunk = Chunk.init(allocator);
    var vm = VM.init();
    defer {
        vm.deinit();
        chunk.deinit();
        _ = gpa.deinit();
    }

    var constant = try chunk.addConstant(Value{ .number = 1.2 });
    try chunk.write(Opcode.CONSTANT.toByte(), 123);
    try chunk.write(@intCast(constant), 123);

    constant = try chunk.addConstant(Value{ .number = 3.4 });
    try chunk.write(Opcode.CONSTANT.toByte(), 123);
    try chunk.write(@intCast(constant), 123);

    try chunk.write(Opcode.ADD.toByte(), 123);

    constant = try chunk.addConstant(Value{ .number = 5.6 });
    try chunk.write(Opcode.CONSTANT.toByte(), 123);
    try chunk.write(@intCast(constant), 123);

    try chunk.write(Opcode.DIVIDE.toByte(), 123);
    try chunk.write(Opcode.NEGATE.toByte(), 123);

    try chunk.write(Opcode.RETURN.toByte(), 123);
}
