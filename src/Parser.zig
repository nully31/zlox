const std = @import("std");
const Compiler = @import("Compiler.zig");
const Scanner = @import("Scanner.zig");
const ValueArray = @import("ValueArray.zig");
const Opcode = @import("Chunk.zig").Opcode;
const Value = @import("value.zig").Value;
const Allocator = std.mem.Allocator;
const Token = Scanner.Token;
const TokenType = Scanner.TokenType;

/// Parser struct.
const Parser = @This();

allocator: Allocator,
compiler: *Compiler,
current: Token,
previous: Token,
hadError: bool,
panicMode: bool,

pub fn init(allocator: Allocator) Parser {
    return .{
        .allcator = allocator,
        .compiler = undefined,
        .current = undefined,
        .previous = undefined,
        .hadError = false,
        .panicMode = false,
    };
}

/// Parse tokens.
/// Since scanning tokens, parsing tokens, and emitting bytecode are pipelined,
/// the parsed expressions are immediately dumped onto a chunk by the parser methods
/// calling the comiler methods inside.
pub fn parse(self: *Parser, compiler: *Compiler) !void {
    self.compiler = compiler;

    self.advance();
    try self.expression();
    self.consume(TokenType.EOF, "Expect end of expression.");
}

/// Steps forward through the token stream.
/// It asks the scanner for the next token and stores it for later use.
fn advance(self: *Parser) void {
    self.previous = self.current;

    while (true) {
        self.current = self.compiler.scanner.scanToken();
        if (self.current.type != TokenType.ERROR) break;

        self.errorAtCurrent(self.current.lexeme);
    }
}

/// Starts parsing with the second highest precedence.
fn expression(self: *Parser) !void {
    try self.parsePrecedence(Precedence.ASSIGNMENT);
}

/// Consumes next token whilst validating its type at the same time.
fn consume(self: *Parser, @"type": TokenType, message: []const u8) void {
    if (self.current.type == @"type") {
        self.advance();
        return;
    }

    self.errorAtCurrent(message);
}

/// Core of the Pratt Parser.
/// It calls the corresponding parsing function defined in the `ParseRule` table
/// to compile a prefix/infix expression taking operators' precedence into account.
fn parsePrecedence(self: *Parser, precedence: Precedence) !void {
    // Read the next token and look up the corresponding prefix parse rule
    self.advance();
    const prefix_rule = ParseRule.getRule(self.previous.type).prefix;
    if (prefix_rule) |rule| {
        try rule(self);
    } else {
        self.@"error"("Expect expression.");
        return;
    }

    // Parse infix operator(s)
    while (@intFromEnum(precedence) <= @intFromEnum(ParseRule.getRule(self.current.type).precedence)) {
        self.advance();
        const infix_rule = ParseRule.getRule(self.previous.type).infix;
        try infix_rule.?(self);
    }
}

fn binary(self: *Parser) !void {
    const operator_type = self.previous.type;
    const rule = ParseRule.getRule(operator_type);

    // Parse operands with higher precedence operators
    // Each binary operator's right-hand operand precedence is one level higher than its own (left-associative)
    try self.parsePrecedence(@enumFromInt(@intFromEnum(rule.precedence) + 1));

    switch (operator_type) {
        .BANG_EQUAL => try self.compiler.emitBytes(@intFromEnum(Opcode.EQUAL), @intFromEnum(Opcode.NOT)), // a != b <-> !(a == b)
        .EQUAL_EQUAL => try self.compiler.emitByte(@intFromEnum(Opcode.EQUAL)),
        .GREATER => try self.compiler.emitByte(@intFromEnum(Opcode.GREATER)),
        .GREATER_EQUAL => try self.compiler.emitBytes(@intFromEnum(Opcode.LESS), @intFromEnum(Opcode.NOT)), // a >= b <-> !(a < b)
        .LESS => try self.compiler.emitByte(@intFromEnum(Opcode.LESS)),
        .LESS_EQUAL => try self.compiler.emitBytes(@intFromEnum(Opcode.GREATER), @intFromEnum(Opcode.NOT)), // a <= b <-> !(a > b)
        .PLUS => try self.compiler.emitByte(@intFromEnum(Opcode.ADD)),
        .MINUS => try self.compiler.emitByte(@intFromEnum(Opcode.SUBTRACT)),
        .STAR => try self.compiler.emitByte(@intFromEnum(Opcode.MULTIPLY)),
        .SLASH => try self.compiler.emitByte(@intFromEnum(Opcode.DIVIDE)),
        else => unreachable,
    }
}

fn literal(self: *Parser) !void {
    switch (self.previous.type) {
        .FALSE => try self.compiler.emitByte(@intFromEnum(Opcode.FALSE)),
        .NIL => try self.compiler.emitByte(@intFromEnum(Opcode.NIL)),
        .TRUE => try self.compiler.emitByte(@intFromEnum(Opcode.TRUE)),
        else => unreachable,
    }
}

fn grouping(self: *Parser) !void {
    try self.expression();
    self.consume(TokenType.RIGHT_PAREN, "Expect ')' after expression.");
}

fn number(self: *Parser) !void {
    const value = Value{ .number = try std.fmt.parseFloat(f64, self.previous.lexeme) };
    try self.compiler.emitConstant(value);
}

fn string(self: *Parser) !void {}

fn unary(self: *Parser) !void {
    const operator_type = self.previous.type;

    // Compile the operand
    try self.parsePrecedence(Precedence.UNARY);

    // Emit the operator instruction
    switch (operator_type) {
        .BANG => try self.compiler.emitByte(@intFromEnum(Opcode.NOT)),
        .MINUS => try self.compiler.emitByte(@intFromEnum(Opcode.NEGATE)),
        else => unreachable,
    }
}

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
const ParseFn = *const fn (self: *Parser) anyerror!void;
const ParseRule = struct {
    prefix: ?ParseFn,
    infix: ?ParseFn,
    precedence: Precedence,

    fn getRule(@"type": TokenType) *const ParseRule {
        return &rules[@intFromEnum(@"type")];
    }

    /// Table for the Pratt parser.
    /// Rows need to be in sync with `TokenType` variants.
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
        .{ .prefix = unary, .infix = null, .precedence = Precedence.NONE }, // BANG
        .{ .prefix = null, .infix = binary, .precedence = Precedence.EQUALITY }, // BANG_EQUAL
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // EQUAL
        .{ .prefix = null, .infix = binary, .precedence = Precedence.EQUALITY }, // EQUAL_EQUAL
        .{ .prefix = null, .infix = binary, .precedence = Precedence.COMPARISON }, // GREATER
        .{ .prefix = null, .infix = binary, .precedence = Precedence.COMPARISON }, // GREATER_EQUAL
        .{ .prefix = null, .infix = binary, .precedence = Precedence.COMPARISON }, // LESS
        .{ .prefix = null, .infix = binary, .precedence = Precedence.COMPARISON }, // LESS_EQUAL
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // IDENTIFIER
        .{ .prefix = string, .infix = null, .precedence = Precedence.NONE }, // STRING
        .{ .prefix = number, .infix = null, .precedence = Precedence.NONE }, // NUMBER
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // AND
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // CLASS
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // ELSE
        .{ .prefix = literal, .infix = null, .precedence = Precedence.NONE }, // FALSE
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // FOR
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // FUN
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // IF
        .{ .prefix = literal, .infix = null, .precedence = Precedence.NONE }, // NIL
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // OR
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // PRINT
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // RETURN
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // SUPER
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // THIS
        .{ .prefix = literal, .infix = null, .precedence = Precedence.NONE }, // TRUE
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // VAR
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // WHILE
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // ERROR
        .{ .prefix = null, .infix = null, .precedence = Precedence.NONE }, // EOF
    };
};

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
