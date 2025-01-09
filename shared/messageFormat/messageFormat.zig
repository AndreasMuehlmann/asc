const std = @import("std");

pub fn main() !void {
    var buffer: [256]u8 = undefined;
    var slice: []u8 = &buffer;
    var index: usize = 0;
    var stringArray: [3]u8 = undefined;
    var string: []u8 = stringArray[0..];

    @memcpy(string[0..], "abc");
    try encodeType(u8, 0xAA, &slice, &index);
    try encodeType(u32, 0xAA, &slice, &index);
    try encodeType(i32, -0xFF, &slice, &index);
    try encodeType(f32, 1.5, &slice, &index);
    try encodeType([]u8, string, &slice, &index);
}

const MessageType = enum {
    U8,
    U32,
    U64,
    I32,
    I64,
    F32,
    F64,
    String,

    pub fn fromType(comptime T: type) ?MessageType {
        if (T == u8) {
            return MessageType.U8;
        } else if (T == u32) {
            return MessageType.U32;
        } else if (T == u64) {
            return MessageType.U64;
        } else if (T == i32) {
            return MessageType.I32;
        } else if (T == i64) {
            return MessageType.I64;
        } else if (T == f32) {
            return MessageType.F32;
        } else if (T == f64) {
            return MessageType.F64;
        } else if (T == []u8) {
            return MessageType.String;
        } else {
            return null;
        }
    }

    pub fn toType(messageType: MessageType) type {
        if (messageType == MessageType.U8) {
            return u8;
        } else if (messageType == MessageType.U32) {
            return u32;
        } else if (messageType == MessageType.U64) {
            return u64;
        } else if (messageType == MessageType.I32) {
            return i32;
        } else if (messageType == MessageType.I64) {
            return i64;
        } else if (messageType == MessageType.F32) {
            return f32;
        } else if (messageType == MessageType.F64) {
            return f64;
        } else if (messageType == MessageType.String) {
            return []u8;
        }
        unreachable;
    }

    pub fn maxInt() u8 {
        return @intFromEnum(MessageType.String);
    }
};

fn encodeType(comptime T: type, value: T, buffer: *[]u8, index: *usize) !void {
    const messageTypeOption = MessageType.fromType(T);

    if (messageTypeOption == null) {
        return error.UnknownMessageType;
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
    } else if (T == u8) {
        buffer.*[index.*] = value;
        index.* += 1;
    } else {
        const byteSize = @sizeOf(T);
        const bytes: *[byteSize]u8 = @ptrCast(@constCast(&value));
        @memcpy(buffer.*[index.* .. index.* + byteSize], bytes);
        index.* += byteSize;
    }
}

fn decodeType(comptime T: type, buffer: *[]u8, index: *usize) !T {
    //if (buffer.*[index.*] > MessageType.maxInt()) {
    //    return error.UnknownMessageType;
    //}
    //const messageType: MessageType = @enumFromInt(buffer.*[index.*]);
    const byteSize = @sizeOf(T);
    if (T == u8) {
        const number = buffer.*[index.*];
        index.* += byteSize;
        return number;
    }

    var bytes: [byteSize]u8 = undefined;
    const bytesPtr: *[byteSize]u8 = &bytes;
    @memcpy(bytesPtr, buffer.*[index.* .. index.* + byteSize]);
    const number: *T = @ptrCast(@constCast(@alignCast(bytesPtr)));
    index.* += byteSize;

    return number.*;
}

test "TestPrimitiveTypeFromType" {
    try std.testing.expect(MessageType.fromType(u8).? == MessageType.U8);
    try std.testing.expect(MessageType.fromType(u32).? == MessageType.U32);
    try std.testing.expect(MessageType.fromType(u64).? == MessageType.U64);
    try std.testing.expect(MessageType.fromType(i32).? == MessageType.I32);
    try std.testing.expect(MessageType.fromType(i64).? == MessageType.I64);
    try std.testing.expect(MessageType.fromType(f32).? == MessageType.F32);
    try std.testing.expect(MessageType.fromType(f64).? == MessageType.F64);
    try std.testing.expect(MessageType.fromType([]u8).? == MessageType.String);
    try std.testing.expect(MessageType.fromType(u16) == null);
}

test "TestEncodePrimitiveType" {
    var buffer: [256]u8 = undefined;
    var slice: []u8 = &buffer;
    var index: usize = 0;
    var stringArray: [3]u8 = undefined;
    var string: []u8 = stringArray[0..];

    @memcpy(string[0..], "abc");
    try encodeType(u8, 0xAA, &slice, &index);
    try encodeType(u32, 0xAA, &slice, &index);
    try encodeType(i32, -0xFF, &slice, &index);
    try encodeType(f32, 1.5, &slice, &index);
    try encodeType([]u8, string, &slice, &index);

    const ordinalU8: u8 = @intFromEnum(MessageType.U8);
    try std.testing.expect(buffer[0] == ordinalU8);
    try std.testing.expect(buffer[1] == 0xAA);

    var decodeIndex: usize = 1;
    try std.testing.expect(try decodeType(u8, &slice, &decodeIndex) == 0xAA);

    const ordinalU32: u8 = @intFromEnum(MessageType.U32);
    try std.testing.expect(buffer[2] == ordinalU32);
    try std.testing.expect(buffer[3] == 0xAA);
    try std.testing.expect(buffer[4] == 0);
    try std.testing.expect(buffer[5] == 0);
    try std.testing.expect(buffer[6] == 0);

    decodeIndex += 1;
    try std.testing.expect(try decodeType(u32, &slice, &decodeIndex) == 0xAA);

    const ordinalI32: u8 = @intFromEnum(MessageType.I32);
    try std.testing.expect(buffer[7] == ordinalI32);
    try std.testing.expect(buffer[8] == 1);
    try std.testing.expect(buffer[11] == 0b11111111);

    const ordinalF32: u8 = @intFromEnum(MessageType.F32);
    try std.testing.expect(buffer[12] == ordinalF32);

    // TODO add checking for float

    const ordinalString: u8 = @intFromEnum(MessageType.String);
    try std.testing.expect(buffer[17] == ordinalString);
    try std.testing.expect(buffer[18] == 3);
    try std.testing.expect(std.mem.eql(u8, buffer[19..22], "abc"));

    try std.testing.expect(index == 22);
}
