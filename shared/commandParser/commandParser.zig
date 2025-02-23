const std = @import("std");
const lexerMod = @import("lexer.zig");
const commandParserUtils = @import("commandParserUtils.zig");

// TODO: Proper error messages

pub const ParserError = error{
    MissingRequiredOption,
    MultipleSameOption,
    UnknownOption,
    OptionWithoutValue,
    CommandNameInvalid,
    UnknownSubcommand,
    SubcommandMustBeStruct,
    UnionUntagged,
    TagTypeHasToBeEnum,
    HelpMessage,
};

pub const FieldDescription = struct {
    fieldName: []const u8,
    description: []const u8,
};

pub fn CommandParser(comptime commandT: type, comptime descriptions: []const FieldDescription) type {
    return struct {
        arena: std.heap.ArenaAllocator,
        lexer: lexerMod.Lexer,
        message: []const u8,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, command: []const u8) Self {
            return .{ .arena = std.heap.ArenaAllocator.init(allocator), .lexer = lexerMod.Lexer.init(command), .message = "" };
        }

        pub fn parse(self: *Self) !commandT {
            const token = try self.lexer.nextToken();
            try self.checkHelp(commandT, token);
            const isHelpNotAsOption = token.type == lexerMod.TokenType.string and std.mem.eql(u8, token.literal, "help");
            if (isHelpNotAsOption) {
                self.message = Self.generateHelpMessage(commandT);
                return ParserError.HelpMessage;
            }
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
            return self.parsePrimitiveType(T, token);
        }

        fn parseStruct(self: *Self, comptime T: type, token: lexerMod.Token) !T {
            if (token.type != lexerMod.TokenType.string or !std.mem.eql(u8, token.literal, commandParserUtils.typeBaseName(T))) {
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

                try self.checkHelp(T, tok);

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

        fn parsePrimitiveType(self: *Self, comptime T: type, token: lexerMod.Token) !T {
            const typeInfo = @typeInfo(T);
            if (token.type == lexerMod.TokenType.string and typeInfo == .Pointer and
                typeInfo.Pointer.size == .Slice and typeInfo.Pointer.child == u8)
            {
                return try self.parseString(token.literal);
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

        fn parseString(self: *Self, string: []const u8) ![]u8 {
            const arenaAllocator = self.arena.allocator();
            var escapedString = std.ArrayList(u8).init(arenaAllocator);

            var escaped: bool = false;

            const str = if (string[0] == '"') string[1 .. string.len - 1] else string;
            for (str) |char| {
                if (escaped) {
                    try escapedString.append(char);
                    escaped = false;
                    continue;
                }

                if (char == '\\') {
                    escaped = true;
                    continue;
                }
                try escapedString.append(char);
            }

            return escapedString.items;
        }

        pub fn generateHelpMessage(comptime T: type) []const u8 {
            const typeInfo = @typeInfo(T);
            if (typeInfo == .Struct) {
                return comptime Self.generateHelpMessageStruct(T);
            } else if (typeInfo == .Union) {
                return comptime Self.generateHelpMessageTaggedUnion(T) ++ "\n";
            }
            unreachable;
        }

        fn generateHelpMessageStruct(comptime T: type) []const u8 {
            const typeInfo = @typeInfo(T);

            comptime var helpMessage: [typeInfo.Struct.fields.len + 1][]const u8 = undefined;

            helpMessage[0] = "-h, --help";

            comptime var maxLength = helpMessage[0].len;
            inline for (1..typeInfo.Struct.fields.len + 1, typeInfo.Struct.fields) |i, field| {
                helpMessage[i] = "";

                const fieldTypeInfo = @typeInfo(field.type);
                if (fieldTypeInfo == .Union) {
                    if (fieldTypeInfo.Union.tag_type == null) {
                        @compileError("Union has to be tagged.");
                    }
                    helpMessage[i] = comptime Self.generateHelpMessageTaggedUnion(field.type);
                } else {
                    if (comptime commandParserUtils.hasAbreviation(T, i - 1)) {
                        helpMessage[i] = helpMessage[i] ++ "-" ++ field.name[0..1] ++ ", ";
                    }
                    helpMessage[i] = helpMessage[i] ++ "--" ++ field.name;

                    if (field.type != bool) {
                        helpMessage[i] = helpMessage[i] ++ " <" ++ comptime commandParserUtils.printableTypeName(field.type) ++ ">";
                    }
                }
                maxLength = @max(maxLength, helpMessage[i].len);
            }

            inline for (1..typeInfo.Struct.fields.len + 1, typeInfo.Struct.fields) |i, field| {
                const descriptionOption = comptime getFieldDescription(field.name);
                if (descriptionOption) |description| {
                    helpMessage[i] = helpMessage[i] ++ comptime commandParserUtils.repeat(" ", (maxLength + 4) - helpMessage[i].len) ++ description;
                }
            }

            comptime var assembledHelpMessage: []const u8 = "";
            inline for (helpMessage) |line| {
                assembledHelpMessage = assembledHelpMessage ++ line ++ "\n";
            }

            return assembledHelpMessage;
        }

        pub fn generateHelpMessageTaggedUnion(comptime T: type) []const u8 {
            comptime var message: []const u8 = commandParserUtils.typeBaseName(T) ++ ": ";

            const tagTypeInfo = @typeInfo(@typeInfo(T).Union.tag_type.?);
            if (tagTypeInfo != .Enum) {
                @compileError("Union has to have enum as tag.");
            }
            inline for (tagTypeInfo.Enum.fields[0 .. tagTypeInfo.Enum.fields.len - 1]) |tagField| {
                message = message ++ tagField.name ++ ", ";
            }
            return message ++ tagTypeInfo.Enum.fields[tagTypeInfo.Enum.fields.len - 1].name;
        }

        fn checkHelp(self: *Self, comptime T: type, token: lexerMod.Token) !void {
            const isHelp = (token.type == lexerMod.TokenType.longOption and std.mem.eql(u8, token.literal, "help")) or
                (token.type == lexerMod.TokenType.shortOption and token.literal[0] == 'h');
            if (isHelp) {
                self.message = Self.generateHelpMessage(T);
                return ParserError.HelpMessage;
            }
        }

        fn getFieldDescription(comptime fieldName: []const u8) ?[]const u8 {
            inline for (descriptions) |fieldDescription| {
                if (comptime std.mem.eql(u8, fieldDescription.fieldName, fieldName)) {
                    return fieldDescription.description;
                }
            }
            return null;
        }

        pub fn deinit(self: Self) void {
            self.arena.deinit();
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
    var commandParser = CommandParser(set, &.{}).init(
        testing.allocator,
        "set --ssid \"Some\\\\Na\\ me\" --password 12\\\\3\\\"45 --optional -1.3 --flag --number -999 -z 500",
    );
    defer commandParser.deinit();
    const setCommand: set = try commandParser.parse();
    try testing.expect(setCommand.flag);
    try testing.expect(!setCommand.flag2);
    try testing.expectEqualStrings("Some\\Na me", setCommand.ssid);
    try testing.expectEqualStrings("12\\3\"45", setCommand.password);
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
    var commandParser = CommandParser(testCommand, &.{}).init(
        testing.allocator,
        "testCommand --flag blue --blue aColor",
    );
    defer commandParser.deinit();
    const testCmd: testCommand = try commandParser.parse();

    try testing.expect(testCmd.flag);
    try testing.expectEqual(@as(SubCommandsEnum, testCmd.subCommands), SubCommandsEnum.blue);
    try testing.expectEqualStrings(testCmd.subCommands.blue.blue, "aColor");
}

test "TestMultipleCommands" {
    var commandParser = CommandParser(SubCommands, &.{}).init(
        testing.allocator,
        "blue --blue aColor",
    );
    defer commandParser.deinit();
    const subCommands: SubCommands = try commandParser.parse();

    try testing.expectEqualStrings(subCommands.blue.blue, "aColor");
}

test "TestGenerateHelpMessage" {
    const descriptions: []const FieldDescription = &.{
        .{ .fieldName = "red", .description = "A color." },
        .{ .fieldName = "road", .description = "Some argument." },
    };

    var commandParser = CommandParser(red, descriptions).init(
        testing.allocator,
        "red --help",
    );
    defer commandParser.deinit();
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

    const commandParserT = CommandParser(SubCommands, descriptions);
    {
        var commandParser = commandParserT.init(
            testing.allocator,
            "blue --help",
        );
        defer commandParser.deinit();
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
    var commandParser = commandParserT.init(
        testing.allocator,
        "help",
    );
    defer commandParser.deinit();
    try testing.expectError(ParserError.HelpMessage, commandParser.parse());
    const expectHelpMessage =
        \\SubCommands: red, blue
        \\
    ;
    _ = commandParser.parse() catch {
        try testing.expectEqualStrings(expectHelpMessage, commandParser.message);
    };
}

test "TestGenerateHelpMessageSubcommands" {
    var commandParser = CommandParser(testCommand, &.{}).init(
        testing.allocator,
        "testCommand --help",
    );
    defer commandParser.deinit();
    try testing.expectError(ParserError.HelpMessage, commandParser.parse());
    const expectHelpMessage =
        \\-h, --help
        \\-f, --flag
        \\SubCommands: red, blue
        \\
    ;
    _ = commandParser.parse() catch {
        try testing.expectEqualStrings(expectHelpMessage, commandParser.message);
    };
}
