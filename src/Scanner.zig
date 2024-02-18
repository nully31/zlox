const std = @import("std");

/// A scanner struct which chews throught the input code.
/// It also tarcks how far it's gone.
const Scanner = @This();

source: []const u8,
start: usize,
current: usize,
line: isize,

/// Token struct.
pub const Token = struct {
    Type: TokenType,
    lexeme: []const u8,
    line: isize,
};

pub fn init(source: []const u8) Scanner {
    return .{
        .source = source,
        .start = 0, // `start` marks the beginning of the current lexeme being scanned
        .current = 0, // `current` points to the current character being look at (that is, to be consumed next)
        .line = 1, // line information for error reporting
    };
}

/// Scan and tokenize the given source input.
/// This is the core method of the scanner struct.
pub fn scanToken(self: *Scanner) Token {
    self.start = self.current;
    if (self.isAtEnd()) return self.makeToken(TokenType.EOF);

    return self.errorToken("Unexpected character.");
}

fn isAtEnd(self: *Scanner) bool {
    return self.current == self.source.len;
}

fn makeToken(self: *Scanner, Type: TokenType) Token {
    return .{ .Type = Type, .lexeme = self.source[self.start..self.current], .line = self.line };
}

fn errorToken(self: *Scanner, message: []const u8) Token {
    return .{
        .Type = TokenType.ERROR,
        .lexeme = message,
        .line = self.line,
    };
}

/// Types of tokens.
pub const TokenType = enum {
    // Single character tokens
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE,
    COMMA,
    DOT,
    MINUS,
    PLUS,
    SEMICOLON,
    SLASH,
    STAR,

    // One or two character tokens
    BANG,
    BANG_EQUAL,
    EQUAL,
    EQUAL_EQUAL,
    GREATER,
    GREATER_EQUAL,
    LESS,
    LESS_EQUAL,

    // Literals
    IDENTIFIER,
    STRING,
    NUMBER,

    // Keywords
    AND,
    CLASS,
    ELSE,
    FALSE,
    FOR,
    FUN,
    IF,
    NIL,
    OR,
    PRINT,
    RETURN,
    SUPER,
    THIS,
    TRUE,
    VAR,
    WHILE,

    ERROR, // Note: might be better moving this out as a new error enum?
    EOF,
};
