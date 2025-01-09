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

fn encodeType(comptime T: type, value: T, buffer: *[]u8, index: *usize) !void {
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
        const bytes: *const [byteSize]u8 = @ptrCast(&value);
        @memcpy(buffer.*[index.* .. index.* + byteSize], bytes);
        index.* += byteSize;
    }
}

fn decodeType(comptime T: type, buffer: *[]u8, index: *usize) !T {
    const byteSize = @sizeOf(T);
    if (T == u8) {
        const number = buffer.*[index.*];
        index.* += byteSize;
        return number;
    }
    var bytes: [byteSize]u8 = undefined;
    const bytesPtr: *[byteSize]u8 = &bytes;
    @memcpy(bytesPtr, buffer.*[index.* .. index.* + byteSize]);
    const number: *T = @ptrCast(@alignCast(bytesPtr));
    index.* += byteSize;

    return number.*;
}

test "TestEncodeDecodeType" {
    var buffer: [256]u8 = undefined;
    var slice: []u8 = &buffer;

    var index: usize = 0;
    var decodeIndex: usize = 0;

    var stringArray: [3]u8 = undefined;
    var string: []u8 = stringArray[0..];
    @memcpy(string[0..], "abc");

    try encodeType(u8, 0xAA, &slice, &index);
    try std.testing.expect(buffer[0] == 0xAA);
    try std.testing.expect(try decodeType(u8, &slice, &decodeIndex) == 0xAA);

    try encodeType(u32, 0xAA, &slice, &index);
    try std.testing.expect(buffer[1] == 0xAA);
    try std.testing.expect(buffer[2] == 0);
    try std.testing.expect(buffer[3] == 0);
    try std.testing.expect(buffer[4] == 0);
    try std.testing.expect(try decodeType(u32, &slice, &decodeIndex) == 0xAA);

    try encodeType(i32, -0xFF, &slice, &index);
    try std.testing.expect(buffer[5] == 1);
    try std.testing.expect(buffer[8] == 0b11111111);
    try std.testing.expect(try decodeType(i32, &slice, &decodeIndex) == -0xFF);

    try encodeType(f32, 1.5, &slice, &index);
    try std.testing.expect(try decodeType(f32, &slice, &decodeIndex) == 1.5);

    try encodeType([]u8, string, &slice, &index);
    try std.testing.expect(buffer[13] == 3);
    try std.testing.expect(std.mem.eql(u8, buffer[14..17], "abc"));
    try std.testing.expect(index == 17);
}
