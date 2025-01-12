const std = @import("std");
const shared = @import("shared.zig");

//TODO: only use buffer without index
//has to be implemented for every specifi implementation
//   pub fn decode(buffer: *[]u8, index: *usize) !void {
//       const decoded = try decodeType(message.Message, buffer, index);
//       switch (decoded) {
//           .testMessage => |*value| try testMessageHandler(value.*),
//           .orientation => |*value| try orientationHandler(value.*),
//       }
//   }
//
//
//

pub const Decoder = struct {
    contractEnum: type,
    contract: type,
    allocator: std.mem.Allocator,
    messageLength: ?usize,
    byteCount: usize,

    var array: [shared.MAX_MESSAGE_LENGTH]u8 = undefined;
    var internalBuffer: []u8 = &array;

    const Self = @This();

    pub fn init(comptime contractEnum: type, comptime contract: type, allocator: std.mem.Allocator) Self {
        return .{ .contractEnum = contractEnum, .contract = contract, .allocator = allocator, .messageLength = null, .byteCount = 0 };
    }

    pub fn decode(self: Self, _bytes: []const u8) !void {
        var bytes = _bytes;
        if (self.messageLength == null) {
            if (bytes.len + self.byteCount < 2) {
                if (bytes.len == 0) {
                    return;
                } else if (bytes.len == 1) {
                    internalBuffer[self.byteCount] = bytes[0];
                    self.byteCount += 1;
                } else {
                    unreachable;
                }
                return;
            } else if (self.byteCount == 1) {
                internalBuffer[self.byteCount] = bytes[0];
                var index: usize = 0;
                self.messageLength = try self.decodeType(u16, &internalBuffer, &index);
                self.byteCount = 0;
                if (bytes.len == 1) {
                    return;
                }
                bytes = bytes[1..];
            } else if (bytes.len >= 2) {
                var index: usize = 0;
                self.messageLength = try self.decodeType(u16, &bytes, &index);
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
                @memcpy(internalBuffer[self.byteCount .. self.byteCount + bytes.len], bytes);
            } else if (bytes.len == bytesNeeded) {
                @memcpy(internalBuffer[self.byteCount .. self.byteCount + bytesNeeded], bytes);
                var index: usize = 0;
                _ = try self.decodeType(self.contract, &internalBuffer, &index);
                // call handler function
            } else {
                @memcpy(internalBuffer[self.byteCount .. self.byteCount + bytesNeeded], bytes);
                var index: usize = 0;
                _ = try self.decodeType(self.contract, &internalBuffer, &index);
                self.messageLength = null;
                // call handler function
                try self.decode(bytes[bytesNeeded..]);
            }
        } else {
            if (bytes.len < self.messageLength.?) {
                @memcpy(internalBuffer[0..bytes.len], bytes);
            } else if (bytes.len == self.messageLength.?) {
                var index: usize = 0;
                _ = try self.decodeType(self.contract, &bytes, &index);
                // call handler function
            } else {
                var index: usize = 0;
                _ = try self.decodeType(self.contract, &bytes, &index);
                // call handler function
                try self.decode(bytes[self.messageLength.?..]);
            }
        }
    }

    pub fn decodeType(self: Self, comptime T: type, buffer: *[]u8, index: *usize) !T {
        const typeInfo = @typeInfo(T);
        if (typeInfo == .Struct) {
            var decodeStruct: T = undefined;
            inline for (typeInfo.Struct.fields) |field| {
                @field(decodeStruct, field.name) = try self.decodeType(field.type, buffer, index);
            }
            return decodeStruct;
        }
        if (typeInfo == .Pointer and typeInfo.Pointer.size == .Slice) {
            const length: u8 = buffer.*[index.*];
            index.* += 1;
            const slice: []typeInfo.Pointer.child = try self.allocator.alloc(typeInfo.Pointer.child, length);
            for (0..length) |i| {
                const childValue: typeInfo.Pointer.child = try self.decodeType(typeInfo.Pointer.child, buffer, index);
                slice[i] = childValue;
            }
            return slice;
        }
        if (typeInfo == .Union and typeInfo.Union.tag_type != null) {
            const tag = buffer.*[index.*];
            index.* += 1;

            var decodeUnion: T = undefined;
            inline for (typeInfo.Union.fields, 0..) |field, i| {
                if (i == tag) {
                    decodeUnion = @unionInit(T, field.name, try self.decodeType(field.type, buffer, index));
                    break;
                }
            }
            return decodeUnion;
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
};
