const std = @import("std");
const clap = @import("lib/zig-clap/clap.zig");
const ch = @import("chunk.zig");
const val = @import("value.zig");
const debug = @import("debug.zig");
const VM = @import("vm.zig").VM;
const Chunk = ch.Chunk;
const Opcode = ch.Opcode;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Parse args
    const params = comptime clap.parseParamsComptime(
        \\-h, --help        Usage: zlox [options]
        \\                  * if no option is provided, zlox runs in interactive mode.
        \\-f, --file <path>  Path to executables
    );

    const parser = .{
        .path = clap.parsers.string,
    };

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parser, .{
        .diagnostic = &diag,
        .allocator = gpa.allocator(),
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }

    var vm = VM.init();
    defer vm.free();
    if (res.args.file) |path| {
        _ = path;
        // runFile(path);
    } else {
        // try repl(&vm);
    }
}
}

test "simple chunk" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var chunk = Chunk.init(allocator);
    var vm = VM.init();
    defer {
        vm.free();
        chunk.free();
        _ = gpa.deinit();
    }
    errdefer std.os.exit(1);

    var constant = try chunk.addConstant(1.2);
    try chunk.write(@intFromEnum(Opcode.OP_CONSTANT), 123);
    try chunk.write(constant, 123);

    constant = try chunk.addConstant(3.4);
    try chunk.write(@intFromEnum(Opcode.OP_CONSTANT), 123);
    try chunk.write(constant, 123);

    try chunk.write(@intFromEnum(Opcode.OP_ADD), 123);

    constant = try chunk.addConstant(5.6);
    try chunk.write(@intFromEnum(Opcode.OP_CONSTANT), 123);
    try chunk.write(constant, 123);

    try chunk.write(@intFromEnum(Opcode.OP_DIVIDE), 123);
    try chunk.write(@intFromEnum(Opcode.OP_NEGATE), 123);

    try chunk.write(@intFromEnum(Opcode.OP_RETURN), 123);
    _ = vm.interpret(&chunk);
}
