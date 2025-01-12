const std = @import("std");
const VM = @import("VM.zig");
const Compiler = @import("Compiler.zig");
const Scanner = @import("Scanner.zig");
const ValueArray = @import("ValueArray.zig");
const obj = @import("object.zig");
const Opcode = @import("Chunk.zig").Opcode;
const Value = @import("value.zig").Value;
const Allocator = std.mem.Allocator;
const Token = Scanner.Token;
const TokenType = Scanner.TokenType;
const Object = obj.Object;
const ObjString = obj.ObjString;

/// Parser struct.
const Parser = @This();

compiler: *Compiler,
current: Token,
previous: Token,
had_error: bool,
panic_mode: bool,

pub fn init() Parser {
    return .{
        .compiler = undefined,
        .current = undefined,
        .previous = undefined,
        .had_error = false,
        .panic_mode = false,
    };
}

/// Parse tokens.
/// Since scanning tokens, parsing tokens, and emitting bytecode are pipelined,
/// the parsed expressions are immediately dumped onto a chunk by the parser methods
/// calling the comiler methods inside.
pub fn parse(self: *Parser, compiler: *Compiler) !void {
    self.compiler = compiler;

    self.advance();
    while (!self.match(TokenType.EOF)) {
        try self.declaration();
    }
}

/// Steps forward through the token stream.
/// It asks the scanner for the next token and stores it for later use.
///
/// It sets the error flag and prints the lexeme string upon encountering an error token.
fn advance(self: *Parser) void {
    self.previous = self.current;

    while (true) {
        self.current = self.compiler.scanner.scanToken();
        if (self.current.type != TokenType.ERROR) break;

        self.errorAtCurrent(self.current.lexeme);
    }
}

/// Consumes current token after validating its type.
/// If fails, it sets the error flag and print the passed message.
fn consume(self: *Parser, T: TokenType, message: []const u8) void {
    if (self.current.type == T) {
        self.advance();
        return;
    }

    self.errorAtCurrent(message);
}

/// Check the type of the current token.
/// If matches, it will consume the token and return `true`.
/// Otherwise, it leaves the token alone and returns `false`.
fn match(self: *Parser, T: TokenType) bool {
    if (!self.check(T)) return false;
    self.advance();
    return true;
}

fn check(self: *Parser, T: TokenType) bool {
    return self.current.type == T;
}

/// Compile a declaration.
///
/// `declaration` -> `varDecl` | `statement` ;
fn declaration(self: *Parser) !void {
    try self.statement();

    if (self.panic_mode) self.synchronize();
}

/// Compile a statement.
///
/// `statement` -> `exprStmt` | `printStmt` ;
fn statement(self: *Parser) !void {
    if (self.match(TokenType.PRINT)) {
        try self.printStatement();
    } else {
        try self.expressionStatement();
    }
}

fn printStatement(self: *Parser) !void {
    try self.expression();
    self.consume(TokenType.SEMICOLON, "Expect ';' after value.");
    try self.compiler.emitByte(Opcode.PRINT.toByte());
}

fn expressionStatement(self: *Parser) !void {
    try self.expression();
    self.consume(TokenType.SEMICOLON, "Expect ';' after expression.");
    try self.compiler.emitByte(Opcode.POP.toByte());
}

/// Starts parsing expression with the second highest precedence.
fn expression(self: *Parser) !void {
    try self.parsePrecedence(Precedence.ASSIGNMENT);
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
        .BANG_EQUAL => try self.compiler.emitBytes(Opcode.EQUAL.toByte(), Opcode.NOT.toByte()), // a != b <-> !(a == b)
        .EQUAL_EQUAL => try self.compiler.emitByte(Opcode.EQUAL.toByte()),
        .GREATER => try self.compiler.emitByte(Opcode.GREATER.toByte()),
        .GREATER_EQUAL => try self.compiler.emitBytes(Opcode.LESS.toByte(), Opcode.NOT.toByte()), // a >= b <-> !(a < b)
        .LESS => try self.compiler.emitByte(Opcode.LESS.toByte()),
        .LESS_EQUAL => try self.compiler.emitBytes(Opcode.GREATER.toByte(), Opcode.NOT.toByte()), // a <= b <-> !(a > b)
        .PLUS => try self.compiler.emitByte(Opcode.ADD.toByte()),
        .MINUS => try self.compiler.emitByte(Opcode.SUBTRACT.toByte()),
        .STAR => try self.compiler.emitByte(Opcode.MULTIPLY.toByte()),
        .SLASH => try self.compiler.emitByte(Opcode.DIVIDE.toByte()),
        else => unreachable,
    }
}

fn literal(self: *Parser) !void {
    switch (self.previous.type) {
        .FALSE => try self.compiler.emitByte(Opcode.FALSE.toByte()),
        .NIL => try self.compiler.emitByte(Opcode.NIL.toByte()),
        .TRUE => try self.compiler.emitByte(Opcode.TRUE.toByte()),
        else => unreachable,
    }
}

fn grouping(self: *Parser) !void {
    try self.expression();
    self.consume(TokenType.RIGHT_PAREN, "Expect ')' after expression.");
}

fn number(self: *Parser) !void {
    const number_value = Value{ .number = try std.fmt.parseFloat(f64, self.previous.lexeme) };
    try self.compiler.emitConstant(number_value);
}

fn string(self: *Parser) !void {
    var str = ObjString.init(self.previous.lexeme[1 .. self.previous.lexeme.len - 1]);
    const value: Value = .{ .obj = try str.obj.create(VM.MMU.obj_allocator) };
    try self.compiler.emitConstant(value);
}

fn unary(self: *Parser) !void {
    const operator_type = self.previous.type;

    // Compile the operand
    try self.parsePrecedence(Precedence.UNARY);

    // Emit the operator instruction
    switch (operator_type) {
        .BANG => try self.compiler.emitByte(Opcode.NOT.toByte()),
        .MINUS => try self.compiler.emitByte(Opcode.NEGATE.toByte()),
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

    fn getRule(T: TokenType) *const ParseRule {
        return &rules[@intFromEnum(T)];
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

/// Prints out where the error occurred.
/// Sets the error flag and going panic mode instead of immediately returning compile error,
/// because we want to resynchronize and keep on parsing.
/// Thus, after a first error is detected, any other errors will get suppressed.
/// Panic mode ends when the parser hits a synchronization point (i.e. statement boundaries).
fn errorAt(self: *Parser, token: *Token, message: []const u8) void {
    if (self.panic_mode) return;
    self.panic_mode = true;
    std.debug.print("[line {d}] Error", .{token.line});

    if (token.type == TokenType.EOF) {
        std.debug.print(" at end", .{});
    } else if (token.type == TokenType.ERROR) {
        // nothing
    } else {
        std.debug.print(" at '{s}'", .{token.lexeme});
    }

    std.debug.print(": {s}\n", .{message});
    self.had_error = true;
}

pub fn @"error"(self: *Parser, message: []const u8) void {
    self.errorAt(&self.previous, message);
}

pub fn errorAtCurrent(self: *Parser, message: []const u8) void {
    self.errorAt(&self.current, message);
}

/// Error synchronization to minimize the number of cascaded compile errors.
/// It exits panic mode upon reaching a synchronization point (i.e. statement boundaries).
fn synchronize(self: *Parser) void {
    self.panic_mode = false;
    // Skips tokens indiscriminately until it reaches something that looks like
    // a statement boundary (e.g. semicolon, control flow or declaration keywords).
    while (self.current.type != TokenType.EOF) {
        if (self.previous.type == TokenType.SEMICOLON) return;
        switch (self.current.type) {
            .CLASS, .FUN, .VAR, .FOR, .IF, .WHILE, .PRINT, .RETURN => return,
            else => {},
        }
        self.advance();
    }
}
