const std = @import("std");
const shared = @import("shared.zig");

pub fn Encoder(contractT: type) type {
    return struct {
        const Self = @This();

        var array: [shared.MAX_MESSAGE_LENGTH]u8 = undefined;
        var internalBuffer: []u8 = &array;

        pub fn encode(comptime T: type, value: T) ![]u8 {
            var index: usize = 2;
            const typeInfoMessage = @typeInfo(contractT);
            inline for (typeInfoMessage.Union.fields) |field| {
                if (T == field.type) {
                    try Self.encodeType(contractT, @unionInit(contractT, field.name, value), &internalBuffer, &index);
                    break;
                }
            }
            internalBuffer[index] = shared.TERMINATION_BYTE;
            index += 1;
            if (index > shared.MAX_MESSAGE_LENGTH) {
                return shared.MessageFormatError.MessageToLong;
            }
            const messageLength: u16 = @intCast(index - 2);
            var lengthEncodingIndex: usize = 0;
            try Self.encodeType(u16, messageLength, &internalBuffer, &lengthEncodingIndex);
            return internalBuffer[0..index];
        }

        pub fn encodeType(comptime T: type, value: T, buffer: *[]u8, index: *usize) !void {
            const typeInfo = @typeInfo(T);
            if (typeInfo == .Struct) {
                inline for (typeInfo.Struct.fields) |field| {
                    const fieldValue = @field(value, field.name);
                    try encodeType(field.type, fieldValue, buffer, index);
                }
            } else if (typeInfo == .Pointer and typeInfo.Pointer.size == .Slice) {
                if (value.len > std.math.maxInt(u8)) {
                    return shared.MessageFormatError.ListTooLong;
                }
                const length: u8 = @intCast(value.len);
                buffer.*[index.*] = length;
                index.* += 1;
                for (value) |childValue| {
                    try encodeType(typeInfo.Pointer.child, childValue, buffer, index);
                }
            } else if (typeInfo == .Union and typeInfo.Union.tag_type != null) {
                const tag = @intFromEnum(@as(typeInfo.Union.tag_type.?, value));
                buffer.*[index.*] = tag;
                index.* += 1;

                inline for (typeInfo.Union.fields, 0..) |field, i| {
                    if (i == tag) {
                        try encodeType(field.type, @field(value, field.name), buffer, index);
                    }
                }
            } else if (T == u8) {
                buffer.*[index.*] = value;
                index.* += 1;
            } else if (typeInfo == .Float or typeInfo == .Int) {
                const byteSize = @sizeOf(T);
                const bytes: *const [byteSize]u8 = @ptrCast(&value);
                @memcpy(buffer.*[index.* .. index.* + byteSize], bytes);
                index.* += byteSize;
            } else {
                unreachable;
            }
        }
    };
}
