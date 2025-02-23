const std = @import("std");

pub fn hasAbreviation(comptime T: type, comptime index: usize) bool {
    const typeInfo = @typeInfo(T);
    if (typeInfo.Struct.fields[index].name[0] == 'h') {
        return false;
    }
    inline for (0..index) |i| {
        if (typeInfo.Struct.fields[index].name[0] == typeInfo.Struct.fields[i].name[0]) {
            return false;
        }
    }
    return true;
}

pub fn printableTypeName(comptime T: type) []const u8 {
    const typeInfo = @typeInfo(T);
    if (typeInfo == .Optional) {
        return "?" ++ printableTypeName(typeInfo.Optional.child);
    }
    if (typeInfo == .Pointer and typeInfo.Pointer.size == .Slice and typeInfo.Pointer.child == u8) {
        return "str";
    }
    return @typeName(T);
}

pub fn typeBaseName(comptime T: type) []const u8 {
    const typeName = @typeName(T);
    const optionalIndex = std.mem.lastIndexOfLinear(u8, typeName, ".");
    return if (optionalIndex) |index| typeName[index + 1 ..] else typeName;
}

pub fn repeat(comptime string: []const u8, comptime count: usize) []const u8 {
    comptime var result: []const u8 = "";
    for (0..count) |_| {
        result = result ++ string;
    }
    return result;
}
