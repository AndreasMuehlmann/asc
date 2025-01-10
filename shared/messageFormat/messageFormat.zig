const std = @import("std");

const allocator = std.heap.page_allocator;

const MessageFormatError = error{
    ListTooLong,
};

pub fn main() !void {
    var buffer: [256]u8 = undefined;
    var slice: []u8 = &buffer;
    var index: usize = 0;
    var stringArray: [3]u8 = undefined;
    var string: []u8 = stringArray[0..];
    @memcpy(string[0..], "abc");

    var decodeIndex: usize = 0;
    const testStruct = .{ .num = 1, .float = 1.5 };
    try encodeType(TestStruct, testStruct, &slice, &index);
    const decodedTestStruct = try decodeType(TestStruct, &slice, &decodeIndex);
    std.debug.print("{d}\n", .{decodedTestStruct.num});

    try encodeType(u8, 0xAA, &slice, &index);
    try encodeType(u32, 0xAA, &slice, &index);
    try encodeType(i32, -0xFF, &slice, &index);
    try encodeType(f32, 1.5, &slice, &index);
    try encodeType([]u8, string, &slice, &index);
}

fn encodeType(comptime T: type, value: T, buffer: *[]u8, index: *usize) !void {
    const typeInfo = @typeInfo(T);
    if (typeInfo == .Struct) {
        inline for (typeInfo.Struct.fields) |field| {
            const fieldValue = @field(value, field.name);
            try encodeType(field.type, fieldValue, buffer, index);
        }
    } else if (typeInfo == .Pointer and typeInfo.Pointer.size == .Slice) {
        if (value.len > std.math.maxInt(u8)) {
            return MessageFormatError.ListTooLong;
        }
        const length: u8 = @intCast(value.len);
        buffer.*[index.*] = length;
        index.* += 1;
        for (value) |childValue| {
            try encodeType(typeInfo.Pointer.child, childValue, buffer, index);
        }
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
    const typeInfo = @typeInfo(T);
    if (typeInfo == .Struct) {
        var decodeStruct: T = undefined;
        inline for (typeInfo.Struct.fields) |field| {
            @field(decodeStruct, field.name) = try decodeType(field.type, buffer, index);
        }
        return decodeStruct;
    }
    if (typeInfo == .Pointer and typeInfo.Pointer.size == .Slice) {
        const length: u8 = buffer.*[index.*];
        index.* += 1;
        const slice: []typeInfo.Pointer.child = try allocator.alloc(typeInfo.Pointer.child, length);
        for (0..length) |i| {
            const childValue: typeInfo.Pointer.child = try decodeType(typeInfo.Pointer.child, buffer, index);
            slice[i] = childValue;
        }
        return slice;
    }
    if (T == u8) {
        const number = buffer.*[index.*];
        index.* += 1;
        return number;
    }
    const byteSize = @sizeOf(T);
    var bytes: [byteSize]u8 = undefined;
    const bytesPtr: *[byteSize]u8 = &bytes;
    @memcpy(bytesPtr, buffer.*[index.* .. index.* + byteSize]);
    const number: *T = @ptrCast(@alignCast(bytesPtr));
    index.* += byteSize;
    return number.*;
}

const TestStruct = struct {
    num: u32,
    float: f64,
};

test "TestEncodeDecodeType" {
    const typeInfo = @typeInfo([]u8);
    try std.testing.expect(typeInfo == .Pointer);
    try std.testing.expect(typeInfo.Pointer.size == .Slice);

    var buffer: [256]u8 = undefined;
    var slice: []u8 = &buffer;

    var index: usize = 0;
    var decodeIndex: usize = 0;

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
    try std.testing.expect(try decodeType(i32, &slice, &decodeIndex) == -0xFF);

    try encodeType(f32, 1.5, &slice, &index);
    try std.testing.expect(try decodeType(f32, &slice, &decodeIndex) == 1.5);

    var arrayU8 = [_]u8{ 'a', 'b', 'c' };
    const sliceU8: []u8 = &arrayU8;
    try encodeType([]u8, sliceU8, &slice, &index);
    const decodedSliceU8 = try decodeType([]u8, &slice, &decodeIndex);
    for (0..sliceU8.len) |i| {
        try std.testing.expect(sliceU8[i] == decodedSliceU8[i]);
    }

    var arrayU32 = [_]u32{ 1, 1000, 100001, 1, 2 };
    const sliceU32: []u32 = &arrayU32;
    try encodeType([]u32, sliceU32, &slice, &index);
    const decodedSliceU32 = try decodeType([]u32, &slice, &decodeIndex);
    for (0..sliceU32.len) |i| {
        try std.testing.expect(sliceU32[i] == decodedSliceU32[i]);
    }

    const testStruct = .{ .num = 1, .float = 1.5 };
    try encodeType(TestStruct, testStruct, &slice, &index);
    const decodedTestStruct = try decodeType(TestStruct, &slice, &decodeIndex);
    try std.testing.expect(testStruct.num == decodedTestStruct.num);
    try std.testing.expect(testStruct.float == decodedTestStruct.float);
}
