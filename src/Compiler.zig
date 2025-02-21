const std = @import("std");
const Chunk = @import("Chunk.zig");
const ValueArray = @import("ValueArray.zig");
const Scanner = @import("Scanner.zig");
const Parser = @import("Parser.zig");
const debug = @import("debug.zig");
const config = @import("config.zig");
const InterpretError = @import("VM.zig").InterpretError;
const Value = @import("value.zig").Value;
const Allocator = std.mem.Allocator;
const Token = Scanner.Token;
const TokenType = Scanner.TokenType;
const Opcode = @import("opcode.zig").Opcode;

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
pub fn compile(self: *Compiler) !void {
    try self.parser.parse(self);
    try self.end();
    return if (self.parser.had_error) InterpretError.INTERPRET_COMPILE_ERROR;
}

/// Emits a return operator.
fn end(self: *Compiler) !void {
    try self.emitReturn();
    if (config.debug_print_code) {
        if (!self.parser.had_error) {
            debug.disassembleChunk(self.compiling_chunk, "code");
        }
    }
}

pub fn emitByte(self: *Compiler, byte: u8) !void {
    try self.compiling_chunk.write(byte, self.parser.previous.line);
}

pub fn emitBytes(self: *Compiler, byte1: u8, byte2: u8) !void {
    try self.emitByte(byte1);
    try self.emitByte(byte2);
}

pub fn emitReturn(self: *Compiler) !void {
    try self.emitByte(Opcode.RETURN.toByte()); // Might be temporary
}

pub fn makeConstant(self: *Compiler, value: Value) !u8 {
    const constant = try self.compiling_chunk.addConstant(value);
    // Up to 256 constants in a chunk since `CONSTANT` instruction uses a single byte for the index operand
    if (constant > std.math.maxInt(u8)) {
        self.parser.@"error"("Too many constants in one chunk.");
        return 0;
    }

    return @intCast(constant);
}

pub fn emitConstant(self: *Compiler, value: Value) !void {
    try self.emitBytes(Opcode.CONSTANT.toByte(), try self.makeConstant(value));
}
