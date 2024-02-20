const std = @import("std");
const Chunk = @import("Chunk.zig");
const ValueArray = @import("ValueArray.zig");
const Scanner = @import("Scanner.zig");
const debug = @import("debug.zig");
const config = @import("config.zig");
const Token = Scanner.Token;
const TokenType = Scanner.TokenType;
const Opcode = Chunk.Opcode;
const InterpretError = @import("VM.zig").InterpretError;

/// Compiler struct.
const Compiler = @This();

source: []const u8,
destination: *Chunk,
scanner: Scanner,
parser: Parser,
compiling_chunk: *Chunk,

pub fn init(source: []const u8, destination: *Chunk) Compiler {
    return .{
        .source = source,
        .destination = destination,
        .scanner = Scanner.init(source),
        .parser = Parser.init(),
        .compiling_chunk = destination, // Might change
    };
}

/// Compiles the given source code.
pub fn run(self: *Compiler) !void {
    self.advance();
    try self.expression();
    self.consume(TokenType.EOF, "Expect end of expression.");
    try self.end();
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

fn end(self: *Compiler) !void {
    try self.emitReturn();
    if (config.debug_print_code) {
        if (!self.parser.hadError) {
            debug.disassembleChunk(self.compiling_chunk, "code");
        }
    }
}

fn expression(self: *Compiler) !void {
    try self.parsePrecedence(Precedence.ASSIGNMENT);
}

fn binary(self: *Compiler) !void {
    const operator_type = self.parser.previous.type;
    const rule = ParseRule.getRule(operator_type);
    try self.parsePrecedence(@enumFromInt(@intFromEnum(rule.precedence) + 1));

    switch (operator_type) {
        TokenType.PLUS => try self.emitByte(@intFromEnum(Opcode.ADD)),
        TokenType.MINUS => try self.emitByte(@intFromEnum(Opcode.SUBTRACT)),
        TokenType.STAR => try self.emitByte(@intFromEnum(Opcode.MULTIPLY)),
        TokenType.SLASH => try self.emitByte(@intFromEnum(Opcode.DIVIDE)),
        else => unreachable,
    }
}

fn grouping(self: *Compiler) !void {
    try self.expression();
    self.consume(TokenType.RIGHT_PAREN, "Expect ')' after expression.");
}

fn number(self: *Compiler) !void {
    const value = try std.fmt.parseFloat(ValueArray.T, self.parser.previous.lexeme);
    try self.emitConstant(value);
}

fn unary(self: *Compiler) !void {
    const operator_type = self.parser.previous.type;

    // Compile the operand
    try self.parsePrecedence(Precedence.UNARY);

    // Emit the operator instruction
    switch (operator_type) {
        TokenType.MINUS => try self.emitByte(@intFromEnum(Opcode.NEGATE)),
        else => unreachable,
    }
}

fn parsePrecedence(self: *Compiler, precedence: Precedence) !void {
    self.advance();
    const prefix_rule = ParseRule.getRule(self.parser.previous.type).prefix;
    if (prefix_rule) |rule| {
        try rule(self);
    } else {
        self.parser.@"error"("Expect expression.");
        return;
    }

    while (@intFromEnum(precedence) <= @intFromEnum(ParseRule.getRule(self.parser.current.type).precedence)) {
        self.advance();
        const infix_rule = ParseRule.getRule(self.parser.previous.type).infix;
        try infix_rule.?(self);
    }
}

fn emitByte(self: *Compiler, byte: u8) !void {
    try self.compiling_chunk.write(byte, self.parser.previous.line);
}

fn emitBytes(self: *Compiler, byte1: u8, byte2: u8) !void {
    try self.emitByte(byte1);
    try self.emitByte(byte2);
}

fn emitReturn(self: *Compiler) !void {
    try self.emitByte(@intFromEnum(Opcode.RETURN)); // Might be temporary
}

fn makeConstant(self: *Compiler, value: ValueArray.T) !u8 {
    const constant = try self.compiling_chunk.addConstant(value);
    // Up to 256 constants in a chunk since `CONSTANT` instruction uses a single byte for the index operand
    if (constant > std.math.maxInt(u8)) {
        self.parser.@"error"("Too many constants in one chunk.");
        return 0;
    }

    return @intCast(constant);
}

fn emitConstant(self: *Compiler, value: ValueArray.T) !void {
    try self.emitBytes(@intFromEnum(Opcode.CONSTANT), try self.makeConstant(value));
}

/// Parser struct.
const Parser = struct {
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
};

const Precedence = enum {
    NONE,
    ASSIGNMENT, // =
    OR, // or
    AND, // and
    EQUALITY, // == !=
    COMPARISON, // < > <= >=
    TERM, // + -
    FACTOR, // * /
    UNARY, // ! -
    CALL, // . ()
    PRIMARY,
};

const ParseFn = *const fn (self: *Compiler) anyerror!void;
const ParseRule = struct {
    prefix: ?ParseFn,
    infix: ?ParseFn,
    precedence: Precedence,

    fn getRule(@"type": TokenType) *const ParseRule {
        return &rules[@intFromEnum(@"type")];
    }

    /// Table for the Pratt parser.
    /// Rows need to be in sync with TokenType variants.
    const rules = [_]ParseRule{
        .{ .prefix = grouping, .infix = null, .precedence = Precedence.NONE }, // LEFT_PAREN
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // RIGHT_PAREN
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // LEFT_BRACE
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // RIGHT BRACE
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // COMMA
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // DOT
        .{ .prefix = unary, .infix = binary, .precedence = Precedence.TERM }, // MINUS
        .{ .prefix = null, .infix = binary, .precedence = Precedence.TERM }, // PLUS
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // SEMICOLON
        .{ .prefix = null, .infix = binary, .precedence = Precedence.FACTOR }, // SLASH
        .{ .prefix = null, .infix = binary, .precedence = Precedence.FACTOR }, // STAR
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // BANG
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // BANG_EQUAL
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // EQUAL
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // EQUAL_EQUAL
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // GREATER
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // GREATER_EQUAL
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // LESS
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // LESS_EQUAL
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // IDENTIFIER
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // STRING
        .{ .prefix = number, .infix = null, .precedence = Precedence.NONE }, // NUMBER
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // AND
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // CLASS
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // ELSE
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // FALSE
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // FOR
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // FUN
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // IF
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // NIL
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // OR
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // PRINT
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // RETURN
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // SUPER
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // THIS
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // TRUE
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // VAR
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // WHILE
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // ERROR
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // EOF
    };
};
