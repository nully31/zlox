const std = @import("std");
const Scanner = @import("Scanner.zig");

/// Compiler struct.
const Compiler = @This();

source: []const u8,
scanner: Scanner,

pub fn init(source: []const u8) Compiler {
    return .{
        .source = source,
        .scanner = Scanner.init(source),
    };
}

/// Compile the given source code.
pub fn run(self: *Compiler) void {
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
        std.debug.print("{s: >13} '{s}'\n", .{ @tagName(token.Type), token.lexeme });

        if (token.Type == Scanner.TokenType.EOF) break;
    }
}
