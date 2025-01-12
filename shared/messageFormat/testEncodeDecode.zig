const std = @import("std");
const encode = @import("encode.zig");
const decode = @import("decode.zig");
const testContract = @import("testContract.zig");

const TestStruct = struct {
    num: u32,
    float: f64,
};

const TestTag = enum(u8) {
    numU8,
    numU32,
};

const TestUnion = union(TestTag) {
    numU8: u8,
    numU32: u32,
};

test "TestEncodeDecodeType" {
    const decoder = decode.Decoder.init(testContract.TestContractEnum, testContract.TestContract, std.testing.allocator);
    const typeInfo = @typeInfo([]u8);

    var array: [256]u8 = undefined;
    var slice: []u8 = &array;

    try std.testing.expect(typeInfo == .Pointer);
    try std.testing.expect(typeInfo.Pointer.size == .Slice);

    var index: usize = 0;
    var decodeIndex: usize = 0;

    try encode.Encoder.encodeType(u8, 0xAA, &slice, &index);
    try std.testing.expect(slice[0] == 0xAA);
    try std.testing.expect(try decoder.decodeType(u8, &slice, &decodeIndex) == 0xAA);

    try encode.Encoder.encodeType(u32, 0xAA, &slice, &index);
    try std.testing.expect(slice[1] == 0xAA);
    try std.testing.expect(slice[2] == 0);
    try std.testing.expect(slice[3] == 0);
    try std.testing.expect(slice[4] == 0);
    try std.testing.expect(try decoder.decodeType(u32, &slice, &decodeIndex) == 0xAA);

    try encode.Encoder.encodeType(i32, -0xFF, &slice, &index);
    try std.testing.expect(try decoder.decodeType(i32, &slice, &decodeIndex) == -0xFF);

    try encode.Encoder.encodeType(f32, 1.5, &slice, &index);
    try std.testing.expect(try decoder.decodeType(f32, &slice, &decodeIndex) == 1.5);

    var arrayU8 = [_]u8{ 'a', 'b', 'c' };
    const sliceU8: []u8 = &arrayU8;
    try encode.Encoder.encodeType([]u8, sliceU8, &slice, &index);
    const decodedSliceU8 = try decoder.decodeType([]u8, &slice, &decodeIndex);
    for (0..sliceU8.len) |i| {
        try std.testing.expect(sliceU8[i] == decodedSliceU8[i]);
    }
    std.testing.allocator.free(decodedSliceU8);

    var arrayU32 = [_]u32{ 1, 1000, 100001, 1, 2 };
    const sliceU32: []u32 = &arrayU32;
    try encode.Encoder.encodeType([]u32, sliceU32, &slice, &index);
    const decodedSliceU32 = try decoder.decodeType([]u32, &slice, &decodeIndex);
    for (0..sliceU32.len) |i| {
        try std.testing.expect(sliceU32[i] == decodedSliceU32[i]);
    }
    std.testing.allocator.free(decodedSliceU32);

    const testStruct = .{ .num = 1, .float = 1.5 };
    try encode.Encoder.encodeType(TestStruct, testStruct, &slice, &index);
    const decodedTestStruct = try decoder.decodeType(TestStruct, &slice, &decodeIndex);
    try std.testing.expect(testStruct.num == decodedTestStruct.num);
    try std.testing.expect(testStruct.float == decodedTestStruct.float);

    const testUnion: TestUnion = .{ .numU8 = 2 };
    try encode.Encoder.encodeType(TestUnion, testUnion, &slice, &index);
    const decodedTestUnion = try decoder.decodeType(TestUnion, &slice, &decodeIndex);
    try std.testing.expect(@intFromEnum(@as(TestTag, testUnion)) == @intFromEnum(@as(TestTag, decodedTestUnion)));
    try std.testing.expect(testUnion.numU8 == decodedTestUnion.numU8);
}

test "TestEncoderDecoder" {
    const encoder = encode.Encoder.init(testContract.TestContractEnum, testContract.TestContract);
    const decoder = decode.Decoder.init(testContract.TestContractEnum, testContract.TestContract, std.testing.allocator);
    const message = testContract.TestMessage{ .x = 1.5, .y = -2, .z = 300 };
    var encodedBuffer: []u8 = try encoder.encode(testContract.TestMessage, message);
    var encodedBufferWithoutLength: []u8 = encodedBuffer[2..];
    var index: usize = 0;
    const decoded = try decoder.decodeType(testContract.TestContract, &encodedBufferWithoutLength, &index);

    try std.testing.expect(decoded.testMessage.x == message.x);
    try std.testing.expect(decoded.testMessage.y == message.y);
    try std.testing.expect(decoded.testMessage.z == message.z);
}
