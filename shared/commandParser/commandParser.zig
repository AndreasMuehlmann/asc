const std = @import("std");
const lexerMod = @import("lexer.zig");

const ParserError = error{
    MissingRequiredOption,
    MultipleSameOption,
    UnknownOption,
    OptionWithoutValue,
    CommandNameInvalid,
    UnknownSubcommand,
    SubcommandMustBeStruct,
};

pub fn CommandParser(comptime commandT: type) type {
    return struct {
        allocator: std.mem.Allocator,
        lexer: lexerMod.Lexer,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, command: []const u8) !Self {
            return .{ .allocator = allocator, .lexer = lexerMod.Lexer.init(command) };
        }

        fn parse(self: *Self) !commandT {
            const token = try self.lexer.nextToken();
            return try self.parseType(commandT, token);
        }

        fn parseType(self: *Self, comptime T: type, token: lexerMod.Token) !T {
            const typeInfo = @typeInfo(T);
            if (typeInfo == .Struct) {
                return try self.parseStruct(T, token);
            }
            if (typeInfo == .Union and typeInfo.Union.tag_type != null) {
                return try self.parseTaggedUnion(T, token);
            }
            if (typeInfo == .Optional) {
                return try self.parseType(typeInfo.Optional.child, token);
            }
            return parsePrimitiveType(T, token);
        }

        fn parseStruct(self: *Self, comptime T: type, token: lexerMod.Token) !T {
            const typeName = @typeName(T);
            const optionalIndex = std.mem.lastIndexOfLinear(u8, typeName, ".");
            const typeBaseName = if (optionalIndex) |index| typeName[index + 1 ..] else typeName;
            if (token.type != lexerMod.TokenType.string or !std.mem.eql(u8, token.literal, typeBaseName)) {
                return ParserError.CommandNameInvalid;
            }

            const typeInfo = @typeInfo(T);
            var parsedStruct: T = undefined;
            var previousOption: ?[]const u8 = null;

            var arr: [typeInfo.Struct.fields.len]bool = undefined;
            const found = &arr;
            @memset(found, false);

            while (true) {
                const tok = try self.lexer.nextToken();
                if (tok.type == lexerMod.TokenType.eof) {
                    break;
                }
                if (tok.type == lexerMod.TokenType.string) {
                    if (previousOption) |prevOption| {
                        inline for (typeInfo.Struct.fields) |field| {
                            if (std.mem.eql(u8, prevOption, field.name)) {
                                @field(parsedStruct, field.name) = try self.parseType(field.type, tok);
                            }
                        }
                        previousOption = null;
                        continue;
                    } else {
                        inline for (typeInfo.Struct.fields) |field| {
                            const fieldTypeInfo = @typeInfo(field.type);
                            if (fieldTypeInfo == .Union and fieldTypeInfo.Union.tag_type != null) {
                                @field(parsedStruct, field.name) = try self.parseTaggedUnion(field.type, tok);
                                break;
                            }
                        }
                        break;
                    }
                }

                if (previousOption != null) {
                    return ParserError.OptionWithoutValue;
                }
                var matched = false;
                inline for (0..typeInfo.Struct.fields.len, typeInfo.Struct.fields) |i, field| {
                    const isMatchingLongOption: bool = tok.type == lexerMod.TokenType.longOption and std.mem.eql(u8, tok.literal, field.name);
                    const isMatchingShortOption: bool = tok.type == lexerMod.TokenType.shortOption and tok.literal[0] == field.name[0];
                    if (isMatchingLongOption or isMatchingShortOption) {
                        matched = true;
                        if (found[i]) {
                            return ParserError.MultipleSameOption;
                        }

                        found[i] = true;

                        if (field.type == bool) {
                            @field(parsedStruct, field.name) = true;
                            break;
                        }

                        previousOption = field.name;
                        break;
                    }
                }
                if (!matched) {
                    return ParserError.UnknownOption;
                }
            }

            inline for (0..typeInfo.Struct.fields.len, typeInfo.Struct.fields) |i, field| {
                if (!found[i]) {
                    if (@typeInfo(field.type) == .Optional) {
                        @field(parsedStruct, field.name) = null;
                    } else if (field.default_value) |default_value| {
                        const default_value_aligned: *align(field.alignment) const anyopaque = @alignCast(default_value);
                        @field(parsedStruct, field.name) = @as(*const field.type, @ptrCast(default_value_aligned)).*;
                    } else if (field.type == bool) {
                        @field(parsedStruct, field.name) = false;
                    } else if (@typeInfo(field.type) == .Union and @typeInfo(field.type).Union.tag_type != null) {} else {
                        return ParserError.MissingRequiredOption;
                    }
                }
            }
            return parsedStruct;
        }

        fn parseTaggedUnion(self: *Self, comptime T: type, token: lexerMod.Token) !T {
            const typeInfo = @typeInfo(T);
            var matched = false;
            var parsedUnion: T = undefined;
            inline for (typeInfo.Union.fields) |field| {
                if (std.mem.eql(u8, token.literal, field.name)) {
                    if (@typeInfo(field.type) != .Struct) {
                        return ParserError.SubcommandMustBeStruct;
                    }

                    const parsedStruct = try self.parseStruct(field.type, token);
                    parsedUnion = @unionInit(T, field.name, parsedStruct);
                    matched = true;
                    break;
                }
            }
            if (!matched) {
                return ParserError.UnknownSubcommand;
            }
            return parsedUnion;
        }

        fn parsePrimitiveType(comptime T: type, token: lexerMod.Token) !T {
            const typeInfo = @typeInfo(T);
            if (typeInfo == .Pointer and typeInfo.Pointer.size == .Slice) {
                return token.literal;
            }
            if (typeInfo == .Float) {
                return try std.fmt.parseFloat(T, token.literal);
            }
            if (typeInfo == .Int) {
                if (typeInfo.Int.signedness == .signed) {
                    return try std.fmt.parseInt(T, token.literal, 0);
                }
                return try std.fmt.parseUnsigned(T, token.literal, 0);
            }
            unreachable;
        }
    };
}

const testing = std.testing;

const set = struct {
    flag: bool,
    flag2: bool,
    ssid: []const u8,
    password: []const u8,
    security: u8 = 2,
    optional: ?f32,
    otherOptional: ?f32,
    number: i32,
    zzz: u64,
};

test "TestParser" {
    var commandParser = try CommandParser(set).init(
        testing.allocator,
        "set --ssid SomeName --password 12345 --optional -1.3 --flag --number -999 -z 500",
    );
    const setCommand: set = try commandParser.parse();
    try testing.expect(setCommand.flag);
    try testing.expect(!setCommand.flag2);
    try testing.expectEqualStrings("SomeName", setCommand.ssid);
    try testing.expectEqualStrings("12345", setCommand.password);
    try testing.expectEqual(2, setCommand.security);
    try testing.expectEqual(-1.3, setCommand.optional);
    try testing.expectEqual(null, setCommand.otherOptional);
    try testing.expectEqual(-999, setCommand.number);
    try testing.expectEqual(500, setCommand.zzz);
}

const testCommand = struct {
    flag: bool,
    subCommands: SubCommands,
};

const SubCommandsEnum = enum {
    red,
    blue,
};

const SubCommands = union(SubCommandsEnum) {
    red: red,
    blue: blue,
};

const red = struct {
    red: bool,
};

const blue = struct {
    blue: []const u8,
};

test "TestSubcommands" {
    var commandParser = try CommandParser(testCommand).init(
        testing.allocator,
        "testCommand --flag blue --blue aColor",
    );
    const testCmd: testCommand = try commandParser.parse();

    try testing.expect(testCmd.flag);
    try testing.expectEqual(@as(SubCommandsEnum, testCmd.subCommands), SubCommandsEnum.blue);
    try testing.expectEqualStrings(testCmd.subCommands.blue.blue, "aColor");
}

test "TestMultipleCommands" {
    var commandParser = try CommandParser(SubCommands).init(
        testing.allocator,
        "blue --blue aColor",
    );
    const subCommands: SubCommands = try commandParser.parse();

    try testing.expectEqualStrings(subCommands.blue.blue, "aColor");
}
