/// Opcode enum.
pub const Opcode = enum(u8) {
    CONSTANT,
    NIL,
    TRUE,
    FALSE,
    POP,
    DEFINE_GLOBAL,
    EQUAL, // a != b can be written as !(a == b), thus no opcode for `!=`
    GREATER, // a <= b <-> !(a > b)
    LESS, // a >= b <-> !(a < b)
    ADD,
    SUBTRACT,
    MULTIPLY,
    DIVIDE,
    NOT,
    NEGATE,
    PRINT,
    RETURN,

    /// Returns a byte which represents the current opcode.
    pub fn toByte(self: Opcode) u8 {
        return @intFromEnum(self);
    }

    /// Returns an opcode literal equivalent to the given `byte`.
    pub fn toOpcode(byte: u8) Opcode {
        return @enumFromInt(byte);
    }
};
