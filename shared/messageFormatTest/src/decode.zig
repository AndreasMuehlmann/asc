const std = @import("std");

pub const MAX_MESSAGE_LENGTH = 1000;
pub const TERMINATION_BYTE = 0xAA;

pub const MessageFormatError = error{
    MessageToLong,
    ListTooLong,
    WrongTerminationByte,
    MessageLargerThenExpected,
    TagTooLarge,
};

pub fn Decoder(comptime contractEnumT: type, comptime contractT: type, comptime handlerT: type) type {
    const typeInfoEnum = @typeInfo(contractEnumT);

    if (typeInfoEnum != .@"enum") {
        @compileError("contractEnumT has to be an enum!");
    }
    comptime var handlerFunctionNames: [typeInfoEnum.@"enum".fields.len][]const u8 = undefined;

    inline for (0..typeInfoEnum.@"enum".fields.len) |index| {
        handlerFunctionNames[index] = comptime std.fmt.comptimePrint("{s}{c}{s}", .{ "handle", std.ascii.toUpper(typeInfoEnum.@"enum".fields[index].name[0]), typeInfoEnum.@"enum".fields[index].name[1..] });
    }

    return struct {
        allocator: std.mem.Allocator,
        handler: *handlerT,

        messageLength: ?usize,
        byteCount: usize,

        var array: [MAX_MESSAGE_LENGTH]u8 = undefined;
        var internalBuffer: []u8 = &array;

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, handler: *handlerT) Self {
            return .{ .allocator = allocator, .handler = handler, .messageLength = null, .byteCount = 0 };
        }

        pub fn decode(self: *Self, _bytes: []const u8) !void {
            var bytes = _bytes;
            if (self.messageLength == null) {
                if (bytes.len + self.byteCount < 2) {
                    if (bytes.len == 0) {} else if (bytes.len == 1) {
                        internalBuffer[self.byteCount] = bytes[0];
                        self.byteCount += 1;
                    } else {
                        unreachable;
                    }
                    return;
                } else if (self.byteCount == 1) {
                    if (bytes.len == 0) {
                        return error.ByteCount1;
                    }
                    internalBuffer[self.byteCount] = bytes[0];
                    try self.decodeMessageLength(internalBuffer);
                    self.byteCount = 0;
                    if (bytes.len == 1) {
                        return;
                    }
                    bytes = bytes[1..];
                } else if (bytes.len >= 2) {
                    try self.decodeMessageLength(bytes);
                    if (bytes.len == 2) {
                        return;
                    }
                    bytes = bytes[2..];
                } else {
                    unreachable;
                }
            }

            if (self.byteCount > 0) {
                const bytesNeeded = self.messageLength.? - self.byteCount;
                if (bytes.len < bytesNeeded) {
                    if (self.byteCount + bytes.len >= internalBuffer.len) {
                        return error.A;
                    }
                    @memcpy(internalBuffer[self.byteCount .. self.byteCount + bytes.len], bytes);
                    self.byteCount += bytes.len;
                } else if (bytes.len == bytesNeeded) {
                    if (self.byteCount + bytesNeeded >= internalBuffer.len) {
                        return error.B;
                    }
                    @memcpy(internalBuffer[self.byteCount .. self.byteCount + bytesNeeded], bytes);
                    try self.decodeMessage(internalBuffer);
                } else {
                    if (self.byteCount + bytesNeeded >= internalBuffer.len) {
                        return error.C;
                    }
                    @memcpy(internalBuffer[self.byteCount .. self.byteCount + bytesNeeded], bytes[0..bytesNeeded]);
                    try self.decodeMessage(internalBuffer);
                    try self.decode(bytes[bytesNeeded..]);
                }
            } else {
                if (bytes.len < self.messageLength.?) {
                    if (bytes.len >= internalBuffer.len) {
                        return error.D;
                    }
                    @memcpy(internalBuffer[0..bytes.len], bytes);
                    self.byteCount = bytes.len;
                } else if (bytes.len == self.messageLength.?) {
                    try self.decodeMessage(bytes);
                } else {
                    const toDecodeBytes = bytes[self.messageLength.?..];
                    try self.decodeMessage(bytes);
                    try self.decode(toDecodeBytes);
                }
            }
        }

        fn callHandler(self: *Self, decoded: contractT) !void {
            const index = @intFromEnum(@as(contractEnumT, decoded));
            inline for (handlerFunctionNames, 0..) |handlerFunctionName, i| {
                if (i == index) {
                    const function = @field(handlerT, handlerFunctionName);
                    try function(self.handler, @field(decoded, typeInfoEnum.@"enum".fields[i].name));
                }
            }
        }

        fn decodeMessageLength(self: *Self, buffer: []const u8) !void {
            var index: usize = 0;
            self.messageLength = try self.decodeType(u16, buffer, &index);
            if (self.messageLength.? > MAX_MESSAGE_LENGTH - 2) {
                return MessageFormatError.MessageToLong;
            }
        }

        fn decodeMessage(self: *Self, buffer: []const u8) !void {
            if (self.messageLength.? - 1 >= buffer.len) {
                return MessageFormatError.MessageLargerThenExpected;
            }
            if (buffer[self.messageLength.? - 1] != TERMINATION_BYTE) {
                return MessageFormatError.WrongTerminationByte;
            }
            var index: usize = 0;
            const decoded = try self.decodeType(contractT, buffer, &index);
            self.byteCount = 0;
            self.messageLength = null;
            try self.callHandler(decoded);
        }

        pub fn decodeType(self: Self, comptime T: type, buffer: []const u8, index: *usize) !T {
            const typeInfo = @typeInfo(T);
            if (typeInfo == .@"struct") {
                var decodeStruct: T = undefined;
                inline for (typeInfo.@"struct".fields) |field| {
                    @field(decodeStruct, field.name) = try self.decodeType(field.type, buffer, index);
                }
                return decodeStruct;
            }
            if (typeInfo == .@"pointer" and typeInfo.@"pointer".size == .@"slice") {
                if (index.* >= buffer.len) {
                    return error.E;
                }
                const length: u8 = buffer[index.*];
                index.* += 1;
                const slice: []typeInfo.@"pointer".child = try self.allocator.alloc(typeInfo.@"pointer".child, length);
                for (0..length) |i| {
                    const childValue: typeInfo.@"pointer".child = try self.decodeType(typeInfo.@"pointer".child, buffer, index);
                    slice[i] = childValue;
                }
                return slice;
            }
            if (typeInfo == .@"union" and typeInfo.@"union".tag_type != null) {
                if (index.* >= buffer.len) {
                    return error.F;
                }
                const tag = buffer[index.*];
                index.* += 1;

                var decodeUnion: T = undefined;
                if (tag >= typeInfo.@"union".fields.len) {
                    return MessageFormatError.TagTooLarge;
                }
                inline for (typeInfo.@"union".fields, 0..) |field, i| {
                    if (i == tag) {
                        decodeUnion = @unionInit(T, field.name, try self.decodeType(field.type, buffer, index));
                        break;
                    }
                }
                return decodeUnion;
            }
            if (T == u8) {
                if (index.* >= buffer.len) {
                    return error.G;
                }
                const number = buffer[index.*];
                index.* += 1;
                return number;
            }
            if (typeInfo == .@"float" or typeInfo == .@"int") {
                const byteSize = @sizeOf(T);
                var bytes: [byteSize]u8 = undefined;
                const bytesPtr: *[byteSize]u8 = &bytes;
                const slice = buffer[index.* .. index.* + byteSize];
                if (slice.len > bytesPtr.*.len) {
                    return error.H;
                }
                @memcpy(bytesPtr, buffer[index.* .. index.* + byteSize]);
                const number: *T = @ptrCast(@alignCast(bytesPtr));
                index.* += byteSize;
                return number.*;
            }
            unreachable;
        }
    };
}
