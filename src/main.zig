const std = @import("std");
const clap = @import("lib/zig-clap/clap.zig");
const Chunk = @import("Chunk.zig");
const ValueArray = @import("ValueArray.zig");
const VM = @import("VM.zig");
const debug = @import("debug.zig");
const Allocator = std.mem.Allocator;
const Opcode = Chunk.Opcode;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Parse args
    const params = comptime clap.parseParamsComptime(
        \\-h, --help        Usage: zlox <path>
        \\                  * If no path is provided, zlox starts in interactive mode.
        \\<path>            Path to lox source code
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
    for (res.positionals) |path| {
        try runFile(&vm, path, gpa.allocator());
    } else {
        try repl(&vm);
    }
}

/// Runs VM which executes the given lox source code specified by `path`.
/// Main program owns the read source input.
fn runFile(vm: *VM, path: []const u8, allocator: Allocator) !void {
    const source: []u8 = try readFile(path, allocator);
    defer allocator.free(source);
    _ = try vm.interpret(source);
}

/// Reads file that is specified by `path` onto heap memory.
fn readFile(path: []const u8, allocator: Allocator) ![]u8 {
    var file = std.fs.cwd().openFile(path, .{}) catch |err| {
        std.debug.print("Could not open file: {} \"{s}\"\n", .{ err, path });
        return err;
    };
    return file.readToEndAlloc(allocator, 1024 * 1024) catch |err| {
        std.debug.print("Could not read file: {}\n", .{err});
        return err;
    }; // 1MB max
}

/// Runs VM in interactive mode, predominantly known as "REPL" (Read-Eval-Print-Loop).
/// Ends reading input after reading an `EOF` (which input is 'Ctrl-D' in common shells).
fn repl(vm: *VM) !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var buf: [1024]u8 = undefined;
    var br = std.io.bufferedReader(stdin);
    var reader = br.reader();
    while (true) {
        try stdout.print("> ", .{});

        if (reader.readUntilDelimiterOrEof(buf[0..], '\n') catch |err| {
            std.debug.print("Could not read input: {}\n", .{err});
            return err;
        }) |line| {
            _ = try vm.interpret(line);
        } else {
            try stdout.print("\n", .{});
            break;
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

    var constant = try chunk.addConstant(1.2);
    try chunk.write(@intFromEnum(Opcode.CONSTANT), 123);
    try chunk.write(constant, 123);

    constant = try chunk.addConstant(3.4);
    try chunk.write(@intFromEnum(Opcode.CONSTANT), 123);
    try chunk.write(constant, 123);

    try chunk.write(@intFromEnum(Opcode.ADD), 123);

    constant = try chunk.addConstant(5.6);
    try chunk.write(@intFromEnum(Opcode.CONSTANT), 123);
    try chunk.write(constant, 123);

    try chunk.write(@intFromEnum(Opcode.DIVIDE), 123);
    try chunk.write(@intFromEnum(Opcode.NEGATE), 123);

    try chunk.write(@intFromEnum(Opcode.RETURN), 123);
}
