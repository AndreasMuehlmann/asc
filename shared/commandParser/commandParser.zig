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
    HelpMessage,
};

const FieldDescription = struct {
    fieldName: []const u8,
    description: []const u8,
};

pub fn CommandParser(comptime commandT: type, comptime descriptions: []const FieldDescription) type {
    return struct {
        allocator: std.mem.Allocator,
        lexer: lexerMod.Lexer,
        message: []const u8,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, command: []const u8) !Self {
            return .{ .allocator = allocator, .lexer = lexerMod.Lexer.init(command), .message = "" };
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
            if (token.type != lexerMod.TokenType.string or !std.mem.eql(u8, token.literal, typeBaseName(T))) {
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
                    const isHelpMessage = (tok.type == lexerMod.TokenType.longOption and std.mem.eql(u8, tok.literal, "help")) or
                        (tok.type == lexerMod.TokenType.shortOption and tok.literal[0] == 'h');
                    if (isHelpMessage) {
                        self.message = Self.generateHelpMessage(T);
                        return ParserError.HelpMessage;
                    }
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

        fn generateHelpMessage(comptime T: type) []const u8 {
            const typeInfo = @typeInfo(T);

            comptime var helpMessage: [typeInfo.Struct.fields.len + 1][]const u8 = undefined;

            helpMessage[0] = "-h, --help";

            comptime var maxLength = helpMessage[0].len;
            inline for (1..typeInfo.Struct.fields.len + 1, typeInfo.Struct.fields) |i, field| {
                helpMessage[i] = "";
                if (comptime hasAbreviation(T, i - 1)) {
                    helpMessage[i] = helpMessage[i] ++ "-" ++ field.name[0..1] ++ ", ";
                }
                helpMessage[i] = helpMessage[i] ++ "--" ++ field.name;

                if (field.type != bool) {
                    helpMessage[i] = helpMessage[i] ++ " <" ++ comptime printableTypeName(field.type) ++ ">";
                }
                maxLength = @max(maxLength, helpMessage[i].len);
            }

            inline for (1..typeInfo.Struct.fields.len + 1, typeInfo.Struct.fields) |i, field| {
                const descriptionOption = comptime getFieldDescription(field.name);
                if (descriptionOption) |description| {
                    helpMessage[i] = helpMessage[i] ++ comptime repeat(" ", (maxLength + 4) - helpMessage[i].len) ++ description;
                }
            }

            comptime var assembledHelpMessage: []const u8 = "";
            inline for (helpMessage) |line| {
                assembledHelpMessage = assembledHelpMessage ++ line ++ "\n";
            }

            return assembledHelpMessage;
        }

        fn hasAbreviation(comptime T: type, comptime index: usize) bool {
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

        fn getFieldDescription(comptime fieldName: []const u8) ?[]const u8 {
            inline for (descriptions) |fieldDescription| {
                if (comptime std.mem.eql(u8, fieldDescription.fieldName, fieldName)) {
                    return fieldDescription.description;
                }
            }
            return null;
        }

        fn printableTypeName(comptime T: type) []const u8 {
            const typeInfo = @typeInfo(T);
            if (typeInfo == .Optional) {
                return "?" ++ printableTypeName(typeInfo.Optional.child);
            }
            if (typeInfo == .Pointer and typeInfo.Pointer.size == .Slice and typeInfo.Pointer.child == u8) {
                return "str";
            }
            return @typeName(T);
        }

        fn typeBaseName(comptime T: type) []const u8 {
            const typeName = @typeName(T);
            const optionalIndex = std.mem.lastIndexOfLinear(u8, typeName, ".");
            return if (optionalIndex) |index| typeName[index + 1 ..] else typeName;
        }

        fn repeat(comptime string: []const u8, comptime count: usize) []const u8 {
            comptime var result: []const u8 = "";
            for (0..count) |_| {
                result = result ++ string;
            }
            return result;
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
    var commandParser = try CommandParser(set, &.{}).init(
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
    road: ?[]const u8,
};

const blue = struct {
    blue: []const u8,
};

test "TestSubcommands" {
    var commandParser = try CommandParser(testCommand, &.{}).init(
        testing.allocator,
        "testCommand --flag blue --blue aColor",
    );
    const testCmd: testCommand = try commandParser.parse();

    try testing.expect(testCmd.flag);
    try testing.expectEqual(@as(SubCommandsEnum, testCmd.subCommands), SubCommandsEnum.blue);
    try testing.expectEqualStrings(testCmd.subCommands.blue.blue, "aColor");
}

test "TestMultipleCommands" {
    var commandParser = try CommandParser(SubCommands, &.{}).init(
        testing.allocator,
        "blue --blue aColor",
    );
    const subCommands: SubCommands = try commandParser.parse();

    try testing.expectEqualStrings(subCommands.blue.blue, "aColor");
}

test "TestGenerateHelpMessage" {
    const descriptions: []const FieldDescription = &.{
        .{ .fieldName = "red", .description = "A color." },
        .{ .fieldName = "road", .description = "Some argument." },
    };

    var commandParser = try CommandParser(red, descriptions).init(
        testing.allocator,
        "red --help",
    );
    try testing.expectError(ParserError.HelpMessage, commandParser.parse());
    const expectHelpMessage =
        \\-h, --help
        \\-r, --red        A color.
        \\--road <?str>    Some argument.
        \\
    ;
    _ = commandParser.parse() catch {
        try testing.expectEqualStrings(expectHelpMessage, commandParser.message);
    };
}

test "TestGenerateHelpMessageMultipleCommands" {
    const descriptions: []const FieldDescription = &.{
        .{ .fieldName = "red", .description = "A color." },
        .{ .fieldName = "road", .description = "Some argument." },
        .{ .fieldName = "blue", .description = "Another color." },
    };

    var commandParser = try CommandParser(SubCommands, descriptions).init(
        testing.allocator,
        "blue --help",
    );
    try testing.expectError(ParserError.HelpMessage, commandParser.parse());
    const expectHelpMessage =
        \\-h, --help
        \\-b, --blue <str>    Another color.
        \\
    ;
    _ = commandParser.parse() catch {
        try testing.expectEqualStrings(expectHelpMessage, commandParser.message);
    };
}
