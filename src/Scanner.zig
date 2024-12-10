const std = @import("std");

/// A scanner struct which chews throught the input code.
/// It also tarcks how far it's gone.
const Scanner = @This();

source: []const u8,
start: usize,
current: usize,
line: usize,

/// Token struct.
pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: usize,
};

pub fn init(source: []const u8) Scanner {
    return .{
        .source = source,
        .start = 0, // `start` marks the beginning of the current lexeme being scanned
        .current = 0, // `current` points to the current character being look at (that is, to be consumed next)
        .line = 1, // line information for error reporting
    };
}

fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

/// Scan and tokenize the given source input.
/// This is the core method of the scanner struct.
pub fn scanToken(self: *Scanner) Token {
    self.skipWhitespace();
    self.start = self.current;
    if (self.isAtEnd()) return self.makeToken(TokenType.EOF);

    const c = self.advance();
    if (isAlpha(c)) return self.identifier();
    if (isDigit(c)) return self.number();

    switch (c) {
        '(' => return self.makeToken(TokenType.LEFT_PAREN),
        ')' => return self.makeToken(TokenType.RIGHT_PAREN),
        '{' => return self.makeToken(TokenType.LEFT_BRACE),
        '}' => return self.makeToken(TokenType.RIGHT_BRACE),
        ';' => return self.makeToken(TokenType.SEMICOLON),
        ',' => return self.makeToken(TokenType.COMMA),
        '.' => return self.makeToken(TokenType.DOT),
        '-' => return self.makeToken(TokenType.MINUS),
        '+' => return self.makeToken(TokenType.PLUS),
        '/' => return self.makeToken(TokenType.SLASH),
        '*' => return self.makeToken(TokenType.STAR),
        '!' => return self.makeToken(if (self.match('=')) TokenType.BANG_EQUAL else TokenType.BANG),
        '=' => return self.makeToken(if (self.match('=')) TokenType.EQUAL_EQUAL else TokenType.EQUAL),
        '<' => return self.makeToken(if (self.match('=')) TokenType.LESS_EQUAL else TokenType.LESS),
        '>' => return self.makeToken(if (self.match('=')) TokenType.GREATER_EQUAL else TokenType.GREATER),
        '"' => return self.string(),
        else => return self.errorToken("Unexpected character."),
    }
}

fn isAtEnd(self: *Scanner) bool {
    return self.current == self.source.len;
}

/// Consumes the current character.
fn advance(self: *Scanner) u8 {
    self.current += 1;
    return self.source[self.current - 1];
}

/// Returns the current character without consuming it (lookahead).
fn peek(self: *Scanner) u8 {
    if (self.isAtEnd()) return '\x00'; // Pseudo-sentinel
    return self.source[self.current];
}

/// Looks ahead of the current character and returns the character
/// without consuming neither it nor the current character.
/// Returns `null` if the current character is the last character (so the next one doesn't exist).
fn peekNext(self: *Scanner) u8 {
    if (self.isAtEnd()) return '\x00'; // Pseudo-sentinel
    return self.source[self.current + 1];
}

/// Consumes the current character if and only if it matches the expected.
fn match(self: *Scanner, expected: u8) bool {
    if (self.isAtEnd()) return false;
    if (self.source[self.current] != expected) return false; // Lookahead
    self.current += 1;
    return true;
}

fn makeToken(self: *Scanner, @"type": TokenType) Token {
    return .{ .type = @"type", .lexeme = self.source[self.start..self.current], .line = self.line };
}

fn errorToken(self: *Scanner, message: []const u8) Token {
    return .{
        .type = TokenType.ERROR,
        .lexeme = message,
        .line = self.line,
    };
}

/// Simply consumes whitespace characters.
fn skipWhitespace(self: *Scanner) void {
    while (true) {
        switch (self.peek()) {
            ' ' => _ = self.advance(),
            '\r' => _ = self.advance(),
            '\t' => _ = self.advance(),
            '\n' => {
                self.line += 1;
                _ = self.advance();
            },
            '/' => {
                if (self.peekNext() == '/') {
                    // A comment goes until the end of the line
                    while (self.peek() != '\n' and !self.isAtEnd()) _ = self.advance();
                } else {
                    return;
                }
            },
            else => return,
        }
    }
}

fn identifier(self: *Scanner) Token {
    while (isAlpha(self.peek()) or isDigit(self.peek())) _ = self.advance();
    return self.makeToken(self.identifierType());
}

/// Finds the matching identifier token by looking up the trie, which stores a set of the keyword strings.
/// It starts with the root node and switches to the matching node with the first letter, then checks the rest of the string.
/// If there are keywords where the tree branches again after the first letter, then it switches against the second letter, and so on.
/// If no matching node is found, it returns the `IDENTIFIER` token type.
fn identifierType(self: *Scanner) TokenType {
    switch (self.source[self.start]) {
        'a' => return self.checkKeyword(1, 2, "nd", TokenType.AND),
        'c' => return self.checkKeyword(1, 4, "lass", TokenType.CLASS),
        'e' => return self.checkKeyword(1, 3, "lse", TokenType.ELSE),
        'f' => if (self.current - self.start > 1) {
            switch (self.source[self.start + 1]) {
                'a' => return self.checkKeyword(2, 3, "lse", TokenType.FALSE),
                'o' => return self.checkKeyword(2, 1, "r", TokenType.FOR),
                'u' => return self.checkKeyword(2, 1, "n", TokenType.FUN),
                else => return TokenType.IDENTIFIER,
            }
        },
        'i' => return self.checkKeyword(1, 1, "f", TokenType.IF),
        'n' => return self.checkKeyword(1, 2, "il", TokenType.NIL),
        'o' => return self.checkKeyword(1, 1, "r", TokenType.OR),
        'p' => return self.checkKeyword(1, 4, "rint", TokenType.PRINT),
        'r' => return self.checkKeyword(1, 5, "eturn", TokenType.RETURN),
        's' => return self.checkKeyword(1, 4, "uper", TokenType.SUPER),
        't' => if (self.current - self.start > 1) {
            switch (self.source[self.start + 1]) {
                'h' => return self.checkKeyword(2, 2, "is", TokenType.THIS),
                'r' => return self.checkKeyword(2, 2, "ue", TokenType.TRUE),
                else => return TokenType.IDENTIFIER,
            }
        },
        'v' => return self.checkKeyword(1, 2, "ar", TokenType.VAR),
        'w' => return self.checkKeyword(1, 4, "hile", TokenType.WHILE),
        else => return TokenType.IDENTIFIER,
    }

    return TokenType.IDENTIFIER;
}

/// Once a prefix is found that it could only be one possible reserved word,
/// this method checks if BOTH the length of the lexeme and the remaining characters match
/// to ensure the scanning token is the correct keyword and returns the corresponding token type.
fn checkKeyword(self: *Scanner, comptime start: usize, comptime length: usize, comptime rest: []const u8, comptime @"type": TokenType) TokenType {
    if (self.current - self.start == start + length and
        std.mem.eql(u8, self.source[self.start + start .. self.start + start + length], rest))
    {
        return @"type";
    }

    return TokenType.IDENTIFIER;
}

fn number(self: *Scanner) Token {
    while (isDigit(self.peek())) _ = self.advance();

    // Look for a fractional part
    if (self.peek() == '.' and isDigit(self.peekNext())) {
        // Consume the "."
        _ = self.advance();

        while (isDigit(self.peek())) _ = self.advance();
    }

    return self.makeToken(TokenType.NUMBER);
}

fn string(self: *Scanner) Token {
    while (self.peek() != '"' and !self.isAtEnd()) {
        if (self.peek() == '\n') self.line += 1;
        _ = self.advance();
    }

    if (self.isAtEnd()) return self.errorToken("Unterminated string.");

    // The closing quote
    _ = self.advance();
    return self.makeToken(TokenType.STRING);
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
