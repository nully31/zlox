const std = @import("std");
const Chunk = @import("Chunk.zig");
const Scanner = @import("Scanner.zig");

/// Compiler struct.
const Compiler = @This();

source: []const u8,
destination: *Chunk,
scanner: Scanner,

pub fn init(source: []const u8, destination: *Chunk) Compiler {
    return .{
        .source = source,
        .destination = destination,
        .scanner = Scanner.init(source),
    };
}

/// Compile the given source code.
pub fn run(self: *Compiler) !void {
    // FIXME: currently this is temporary driver code
    var line: isize = -1;
    while (true) {
        const token = self.scanner.scanToken();
        if (token.line != line) {
            std.debug.print("{d: >4} ", .{token.line});
            line = token.line;
        } else {
            std.debug.print("{s: >4} ", .{"|"});
        }
        std.debug.print("{s: >13} '{s}'\n", .{ @tagName(token.type), token.lexeme });

        if (token.type == Scanner.TokenType.EOF) break;
    }
}
