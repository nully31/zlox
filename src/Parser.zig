const std = @import("std");
const Scanner = @import("Scanner.zig");
const Token = Scanner.Token;
const TokenType = Scanner.TokenType;

/// Parser struct.
const Parser = @This();

current: Token,
previous: Token,
hadError: bool,
panicMode: bool,

pub fn init() Parser {
    return .{
        .current = undefined,
        .previous = undefined,
        .hadError = false,
        .panicMode = false,
    };
}

/// Prints where the error occurred.
/// Sets the error flag and going panic mode instead of immediately returning compile error,
/// because we want to resynchronize and keep on parsing.
/// Thus, after a first error is detected, any other errors will get suppressed.
/// Panic mode ends when the parser hits a synchronization point (i.e. statement boundaries).
fn errorAt(self: *Parser, token: *Token, message: []const u8) void {
    if (self.panicMode) return;
    self.panicMode = true;
    std.debug.print("[line {d}] Error", .{token.line});

    if (token.type == TokenType.EOF) {
        std.debug.print(" at end", .{});
    } else if (token.type == TokenType.ERROR) {
        // Nothing
    } else {
        std.debug.print(" at '{s}'", .{token.lexeme});
    }

    std.debug.print(": {s}\n", .{message});
    self.hadError = true;
}

pub fn @"error"(self: *Parser, message: []const u8) void {
    self.errorAt(&self.previous, message);
}

pub fn errorAtCurrent(self: *Parser, message: []const u8) void {
    self.errorAt(&self.current, message);
}
