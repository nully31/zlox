const std = @import("std");
const Chunk = @import("Chunk.zig");
const Scanner = @import("Scanner.zig");
const Parser = @import("Parser.zig");
const Token = Scanner.Token;
const TokenType = Scanner.TokenType;
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
    // Front end
    self.advance();
    // self.expression();
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

fn emitByte(self: *Compiler, byte: u8) !void {
    try self.compiling_chunk.write(byte, self.parser.previous.line);
}

fn emitBytes(self: *Compiler, byte1: u8, byte2: u8) !void {
    try self.emitByte(byte1);
    try self.emitByte(byte2);
}

fn emitReturn(self: *Compiler) !void {
    try self.emitByte(@intFromEnum(TokenType.RETURN)); // Might be temporary
}

fn end(self: *Compiler) !void {
    try self.emitReturn();
}

// Might not be necessary
fn currentChunk(self: *Compiler) *Chunk {
    return self.compiling_chunk;
}
