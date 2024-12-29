const std = @import("std");

const primitiveTypes = enum {
    U8,
    U32,
    U64,
    I32,
    I64,
    F32,
    F64,
    String,

    pub fn fromType(comptime T: type) ?primitiveTypes {
        if (T == u8) {
            return primitiveTypes.U8;
        } else if (T == u32) {
            return primitiveTypes.U32;
        } else if (T == u64) {
            return primitiveTypes.U64;
        } else if (T == i32) {
            return primitiveTypes.I32;
        } else if (T == i64) {
            return primitiveTypes.I64;
        } else if (T == f32) {
            return primitiveTypes.F32;
        } else if (T == f64) {
            return primitiveTypes.F64;
        } else if (T == []u8) {
            return primitiveTypes.String;
        } else {
            return null;
        }
    }
};

fn encodePrimitiveType(comptime T: type, value: T, buffer: *const []u8, index: *usize) !void {
    const messageTypeOption = primitiveTypes.fromType(T);
    if (messageTypeOption == null) {
        return error.UnknownPrimitiveType;
    }
    const messageType = messageTypeOption.?;

    buffer.*[index.*] = @intFromEnum(messageType);
    index.* += 1;

    if (T == []u8) {
        if (value.len > std.math.maxInt(u8)) {
            return error.StringTooLong;
        }
        const length: u8 = @intCast(value.len);
        buffer.*[index.*] = length;
        index.* += 1;
        @memcpy(buffer.*[index.* .. index.* + value.len], value);
        index.* += value.len;
    } else {
        const byteSize = @sizeOf(T);
        const sameSizedUnsignedType = switch (T) {
            u8 => u8,
            u64 => u64,
            u32 => u32,
            i64 => u64,
            i32 => u32,
            f64 => u64,
            f32 => u32,
            else => unreachable,
        };
        for (0..byteSize) |count| {
            const unsigned: sameSizedUnsignedType = @bitCast(value);
            const byte: u8 = @truncate(std.math.shr(sameSizedUnsignedType, unsigned, ((byteSize - count - 1) * 8)));
            buffer.*[index.*] = byte;
            index.* += 1;
        }
    }
}

test "TestPrimitiveTypeFromType" {
    try std.testing.expect(primitiveTypes.fromType(u32).? == primitiveTypes.U32);
    try std.testing.expect(primitiveTypes.fromType(u64).? == primitiveTypes.U64);
    try std.testing.expect(primitiveTypes.fromType(i32).? == primitiveTypes.I32);
    try std.testing.expect(primitiveTypes.fromType(i64).? == primitiveTypes.I64);
    try std.testing.expect(primitiveTypes.fromType(f32).? == primitiveTypes.F32);
    try std.testing.expect(primitiveTypes.fromType(f64).? == primitiveTypes.F64);
    try std.testing.expect(primitiveTypes.fromType([]u8).? == primitiveTypes.String);
    try std.testing.expect(primitiveTypes.fromType(u16) == null);
}

test "TestEncodePrimitiveType" {
    var buffer: [256]u8 = undefined;
    var index: usize = 0;
    var stringArray: [3]u8 = undefined;
    var string: []u8 = stringArray[0..];

    @memcpy(string[0..], "abc");
    try encodePrimitiveType(u8, 0xAA, &buffer[0..], &index);
    try encodePrimitiveType(u32, 0xAA, &buffer[0..], &index);
    try encodePrimitiveType(i32, -0xFF, &buffer[0..], &index);
    try encodePrimitiveType(f32, 1.5, &buffer[0..], &index);
    try encodePrimitiveType([]u8, string, &buffer[0..], &index);

    const ordinalU8: u8 = @intFromEnum(primitiveTypes.U8);
    try std.testing.expect(buffer[0] == ordinalU8);
    try std.testing.expect(buffer[1] == 0xAA);

    const ordinalU32: u8 = @intFromEnum(primitiveTypes.U32);
    try std.testing.expect(buffer[2] == ordinalU32);
    try std.testing.expect(buffer[3] == 0);
    try std.testing.expect(buffer[4] == 0);
    try std.testing.expect(buffer[5] == 0);
    try std.testing.expect(buffer[6] == 0xAA);

    const ordinalI32: u8 = @intFromEnum(primitiveTypes.I32);
    try std.testing.expect(buffer[7] == ordinalI32);
    try std.testing.expect(buffer[8] == 0b11111111);
    try std.testing.expect(buffer[11] == 1);

    const ordinalF32: u8 = @intFromEnum(primitiveTypes.F32);
    try std.testing.expect(buffer[12] == ordinalF32);

    // TODO add checking for float

    const ordinalString: u8 = @intFromEnum(primitiveTypes.String);
    try std.testing.expect(buffer[17] == ordinalString);
    try std.testing.expect(buffer[18] == 3);
    try std.testing.expect(std.mem.eql(u8, buffer[19..22], "abc"));

    try std.testing.expect(index == 22);
}
