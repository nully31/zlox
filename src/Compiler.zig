const std = @import("std");
const Chunk = @import("Chunk.zig");
const Scanner = @import("Scanner.zig");
const Token = Scanner.Token;
const TokenType = Scanner.TokenType;
const InterpretError = @import("VM.zig").InterpretError;

/// Compiler struct.
const Compiler = @This();

const Parser = struct {
    current: Token,
    previous: Token,
    hadError: bool,
    panicMode: bool,

    fn init() Parser {
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

    fn @"error"(self: *Parser, message: []const u8) void {
        self.errorAt(&self.previous, message);
    }

    fn errorAtCurrent(self: *Parser, message: []const u8) void {
        self.errorAt(&self.current, message);
    }
};

source: []const u8,
destination: *Chunk,
scanner: Scanner,
parser: Parser,

pub fn init(source: []const u8, destination: *Chunk) Compiler {
    return .{
        .source = source,
        .destination = destination,
        .scanner = Scanner.init(source),
        .parser = undefined,
    };
}

/// Compiles the given source code.
pub fn run(self: *Compiler) !void {
    // Front end
    self.parser = Parser.init();

    self.advance();
    // self.expression();
    self.consume(TokenType.EOF, "Expect end of expression.");
    return if (self.parser.hadError) InterpretError.INTERPRET_COMPILE_ERROR;
}

/// Steps forward through the token stream.
/// It asks the scanner for the next token and stores it for later use.
fn advance(self: *Compiler) void {
    self.parser.previous = self.parser.current;

    while (true) {
        self.parser.current = self.scanner.scanToken();
        if (self.parser.current.type != TokenType.ERROR) break;

        self.parser.errorAtCurrent(self.parser.current.lexeme);
    }
}

/// Consumes next token whilst validating its type at the same time.
fn consume(self: *Compiler, @"type": TokenType, message: []const u8) void {
    if (self.parser.current.type == @"type") {
        self.advance();
        return;
    }

    self.parser.errorAtCurrent(message);
}
