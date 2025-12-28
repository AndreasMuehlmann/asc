const std = @import("std");
const encode = @import("encode.zig");
const decode = @import("decode.zig");

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

pub const TestMessage = struct {
    x: f32,
    y: i32,
    z: u64,
};

pub const TestContractEnum = enum(u8) {
    testMessage,
};

pub const TestContract = union(TestContractEnum) {
    testMessage: TestMessage,
};

const TestHandler = struct {
    expectedX: f32,
    expectedY: i32,
    expectedZ: u64,

    pub fn handleTestMessage(self: *TestHandler, testMessage: TestMessage) !void {
        try std.testing.expect(self.expectedX == testMessage.x);
        try std.testing.expect(self.expectedY == testMessage.y);
        try std.testing.expect(self.expectedZ == testMessage.z);
    }
};

test "TestEncodeDecodeType" {
    const allocator = std.testing.allocator;
    var handler: TestHandler = .{ .expectedX = 0, .expectedY = 0, .expectedZ = 0 };
    const decoder = decode.Decoder(TestContractEnum, TestContract, TestHandler).init(allocator, &handler);
    const Encoder = encode.Encoder(TestContract);

    var array: [256]u8 = undefined;
    const slice: []u8 = &array;

    var index: usize = 0;
    var decodeIndex: usize = 0;

    try Encoder.encodeType(u8, 0xAA, slice, &index);
    try std.testing.expect(slice[0] == 0xAA);
    try std.testing.expect(try decoder.decodeType(u8, slice, &decodeIndex) == 0xAA);

    try Encoder.encodeType(u32, 0xAA, slice, &index);
    try std.testing.expect(slice[1] == 0xAA);
    try std.testing.expect(slice[2] == 0);
    try std.testing.expect(slice[3] == 0);
    try std.testing.expect(slice[4] == 0);
    try std.testing.expect(try decoder.decodeType(u32, slice, &decodeIndex) == 0xAA);

    try Encoder.encodeType(i32, -0xFF, slice, &index);
    try std.testing.expect(try decoder.decodeType(i32, slice, &decodeIndex) == -0xFF);

    try Encoder.encodeType(f32, 1.5, slice, &index);
    try std.testing.expect(try decoder.decodeType(f32, slice, &decodeIndex) == 1.5);

    var arrayU8 = [_]u8{ 'a', 'b', 'c' };
    const sliceU8: []u8 = &arrayU8;
    try Encoder.encodeType([]u8, sliceU8, slice, &index);
    const decodedSliceU8 = try decoder.decodeType([]u8, slice, &decodeIndex);
    for (0..sliceU8.len) |i| {
        try std.testing.expect(sliceU8[i] == decodedSliceU8[i]);
    }
    std.testing.allocator.free(decodedSliceU8);

    var arrayU32 = [_]u32{ 1, 1000, 100001, 1, 2 };
    const sliceU32: []u32 = &arrayU32;
    try Encoder.encodeType([]u32, sliceU32, slice, &index);
    const decodedSliceU32 = try decoder.decodeType([]u32, slice, &decodeIndex);
    for (0..sliceU32.len) |i| {
        try std.testing.expect(sliceU32[i] == decodedSliceU32[i]);
    }
    std.testing.allocator.free(decodedSliceU32);

    const testStruct: TestStruct = .{ .num = 1, .float = 1.5 };
    try Encoder.encodeType(TestStruct, testStruct, slice, &index);
    const decodedTestStruct = try decoder.decodeType(TestStruct, slice, &decodeIndex);
    try std.testing.expect(testStruct.num == decodedTestStruct.num);
    try std.testing.expect(testStruct.float == decodedTestStruct.float);

    const testUnion: TestUnion = .{ .numU8 = 2 };
    try Encoder.encodeType(TestUnion, testUnion, slice, &index);
    const decodedTestUnion = try decoder.decodeType(TestUnion, slice, &decodeIndex);
    try std.testing.expect(@intFromEnum(@as(TestTag, testUnion)) == @intFromEnum(@as(TestTag, decodedTestUnion)));
    try std.testing.expect(testUnion.numU8 == decodedTestUnion.numU8);
}

test "TestEncoderDecoder" {
    const allocator = std.testing.allocator;

    const Encoder = encode.Encoder(TestContract);

    var handler: TestHandler = .{ .expectedX = 1.5, .expectedY = -2, .expectedZ = 300 };
    const message: TestMessage = .{ .x = 1.5, .y = -2, .z = 300 };

    var decoder = decode.Decoder(TestContractEnum, TestContract, TestHandler).init(allocator, &handler);

    const encoded = try Encoder.encode(TestMessage, message);

    var encodedMessages = try std.ArrayList(u8).initCapacity(allocator, 10);
    try encodedMessages.appendSlice(allocator, encoded);
    try encodedMessages.appendSlice(allocator, encoded);
    try encodedMessages.appendSlice(allocator, encoded);
    try encodedMessages.appendSlice(allocator, encoded);
    try encodedMessages.appendSlice(allocator, encoded);
    try encodedMessages.appendSlice(allocator, encoded);

    try decoder.decode(encodedMessages.items[0..0]);
    try decoder.decode(encodedMessages.items[0..1]);
    try decoder.decode(encodedMessages.items[1..2]);
    try decoder.decode(encodedMessages.items[2 .. encoded.len - 5]);
    try decoder.decode(encodedMessages.items[encoded.len - 5 .. encoded.len - 2]);
    try decoder.decode(encodedMessages.items[encoded.len - 2 .. encoded.len + 5]);
    try decoder.decode(encodedMessages.items[encoded.len + 5 .. 2 * encoded.len]);
    try decoder.decode(encodedMessages.items[2 * encoded.len .. 3 * encoded.len]);
    try decoder.decode(encodedMessages.items[3 * encoded.len .. 5 * encoded.len]);
    try decoder.decode(encodedMessages.items[5 * encoded.len .. 5 * encoded.len + 1]);
    try decoder.decode(encodedMessages.items[5 * encoded.len + 1 .. 6 * encoded.len]);

    encodedMessages.deinit(allocator);
}


const serverContract = @import("serverContract.zig");


const TestHandlerServerContract = struct {
    pub fn handleCommand(_: *TestHandlerServerContract, _: serverContract.command) !void {}
};

test "TestEncodeDecodeServerContract" {
    const allocator = std.testing.allocator;

    const Encoder = encode.Encoder(serverContract.ServerContract);

    var handler: TestHandlerServerContract = .{};

   const command: serverContract.command = serverContract.command{ .setSpeed = serverContract.setSpeed{
       .speed = (0 + 1.0) / 2.0,
   } };

    var decoder = decode.Decoder(serverContract.ServerContractEnum, serverContract.ServerContract, TestHandlerServerContract).init(allocator, &handler);

    const encoded = try Encoder.encode(serverContract.command, command);
    var decodeIndex: usize = 0;
    const length: u16 = try decoder.decodeType(u16, encoded, &decodeIndex);
    std.debug.print("encoded lenght {d}\n", .{length});
    std.debug.print("buffer length {d}\n", .{encoded.len});
     for (encoded[2..]) |value| {
        std.debug.print("{d}\n", .{value});
    }

    var encodedMessages = try std.ArrayList(u8).initCapacity(allocator, 10);
    try encodedMessages.appendSlice(allocator, encoded);
    try decoder.decode(encodedMessages.items);
    encodedMessages.deinit(allocator);
}
