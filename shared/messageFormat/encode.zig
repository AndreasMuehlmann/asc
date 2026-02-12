const std = @import("std");

pub const MAX_MESSAGE_LENGTH = 1000;
pub const TERMINATION_BYTE = 0xAA;

pub const MessageFormatError = error{
    NotSupportedDataType,
    MessageToLong,
    ListTooLong,
    WrongTerminationByte,
};

pub fn Encoder(contractT: type) type {
    return struct {
        const Self = @This();

        var array: [MAX_MESSAGE_LENGTH]u8 = undefined;
        var internalBuffer: []u8 = &array;

        pub fn encode(comptime T: type, value: T) ![]u8 {
            var index: usize = 2;
            const typeInfoMessage = @typeInfo(contractT);
            inline for (typeInfoMessage.@"union".fields) |field| {
                // TODO: check if there are any matches here
                if (T == field.type) {
                    try Self.encodeType(contractT, @unionInit(contractT, field.name, value), internalBuffer, &index);
                    break;
                }
            }
            internalBuffer[index] = TERMINATION_BYTE;
            index += 1;
            if (index > MAX_MESSAGE_LENGTH) {
                return MessageFormatError.MessageToLong;
            }
            const messageLength: u16 = @intCast(index - 2);
            var lengthEncodingIndex: usize = 0;
            try Self.encodeType(u16, messageLength, internalBuffer, &lengthEncodingIndex);
            return internalBuffer[0..index];
        }

        pub fn encodeType(comptime T: type, value: T, buffer: []u8, index: *usize) !void {
            const typeInfo = @typeInfo(T);
            if (typeInfo == .@"struct") {
                inline for (typeInfo.@"struct".fields) |field| {
                    const fieldValue = @field(value, field.name);
                    try encodeType(field.type, fieldValue, buffer, index);
                }
            } else if (typeInfo == .@"pointer" and typeInfo.@"pointer".size == .@"slice") {
                if (value.len > std.math.maxInt(u8)) {
                    return MessageFormatError.ListTooLong;
                }
                const length: u8 = @intCast(value.len);
                buffer[index.*] = length;
                index.* += 1;
                for (value) |childValue| {
                    try encodeType(typeInfo.@"pointer".child, childValue, buffer, index);
                }
            } else if (typeInfo == .@"union" and typeInfo.@"union".tag_type != null) {
                const tagType = typeInfo.@"union".tag_type.?;
                const tagTypeInfo = @typeInfo(tagType);
                if (tagTypeInfo.@"enum".tag_type != u8) {
                    @compileError("The underlying type of the tag " ++ @typeName(tagType) ++ " of the union " ++ @typeName(T) ++ "should be a u8");
                }
                const tag = @intFromEnum(@as(tagType, value));
                buffer[index.*] = tag;
                index.* += 1;

                inline for (typeInfo.@"union".fields, 0..) |field, i| {
                    if (i == tag) {
                        try encodeType(field.type, @field(value, field.name), buffer, index);
                    }
                }
            } else if (typeInfo == .@"enum") {
                if (typeInfo.@"enum".tag_type != u8) {
                    @compileError("The underlying type of the Enum " ++ @typeName(T) ++ "should be a u8");
                }
                const tag: u8 = @intFromEnum(value);
                buffer[index.*] = tag;
                index.* += 1;
            } else if (T == u8) {
                buffer[index.*] = value;
                index.* += 1;
            } else if (typeInfo == .@"float" or typeInfo == .@"int") {
                const byteSize = @sizeOf(T);
                const bytes: *const [byteSize]u8 = @ptrCast(&value);
                @memcpy(buffer[index.* .. index.* + byteSize], bytes);
                index.* += byteSize;
            } else {
                return MessageFormatError.NotSupportedDataType;
            }
        }
    };
}
