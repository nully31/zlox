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

fn isDigit(char: u8) bool {
    return char >= '0' and char <= '9';
}

/// Scan and tokenize the given source input.
/// This is the core method of the scanner struct.
pub fn scanToken(self: *Scanner) Token {
    self.skipWhitespace();
    self.start = self.current;
    if (self.isAtEnd()) return self.makeToken(TokenType.EOF);

    const c = self.advance();
    if (isDigit(c)) return number();

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
    return self.source[self.current];
}

/// Looks ahead of the current character and returns the character
/// without consuming neither it nor the current character.
/// Returns `null` if the current character is the last character (so the next one doesn't exist).
fn peekNext(self: *Scanner) ?u8 {
    if (self.isAtEnd()) return null;
    return self.source[self.current + 1];
}

/// Consumes the current character if and only if it matches the expected.
fn match(self: *Scanner, expected: u8) bool {
    if (self.isAtEnd()) return false;
    if (self.source[self.current] != expected) return false; // Lookahead
    self.current += 1;
    return true;
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

/// Simply consumes whitespace characters.
fn skipWhitespace(self: *Scanner) void {
    while (true) {
        switch (self.peek()) {
            ' ' => self.advance(),
            '\r' => self.advance(),
            '\t' => self.advance(),
            '\n' => {
                self.line += 1;
                self.advance();
            },
            '/' => {
                if (self.peekNext()) |c| {
                    if (c == '/') {
                        // A comment goes until the end of the line
                        while (self.peek() != '\n' and !self.isAtEnd()) self.advance();
                    } else {
                        return;
                    }
                } else {
                    return;
                }
            },
            else => return,
        }
    }
}

fn number(self: *Scanner) Token {
    while (isDigit(self.peek())) self.advance();

    // Look for a fractional part
    if (self.peek() == '.' and isDigit(self.peekNext())) {
        // Consume the "."
        self.advance();

        while (isDigit(self.peek())) self.advance();
    }

    return self.makeToken(TokenType.NUMBER);
}

fn string(self: *Scanner) Token {
    while (self.peek() != '"' and !self.isAtEnd()) {
        if (self.peek() == '\n') self.line += 1;
        self.advance();
    }

    if (self.isAtEnd()) return self.errorToken("Unterminated string.");

    // The closing quote
    self.advance();
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
