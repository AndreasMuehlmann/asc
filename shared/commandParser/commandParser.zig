const std = @import("std");
const lexerMod = @import("lexer.zig");
const commandParserUtils = @import("commandParserUtils.zig");

pub const ParserError = error{
    MissingRequiredOption,
    MultipleSameOption,
    UnknownOption,
    OptionWithoutValue,
    CommandNameInvalid,
    UnknownSubcommand,
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
            const arena = std.heap.ArenaAllocator.init(allocator);
            return .{ .arena = arena, .lexer = lexerMod.Lexer.init(command), .message = "" };
        }

        fn handleErrorNextToken(self: *Self) !lexerMod.Token {
            const allocator = self.arena.allocator();
            const token = self.lexer.nextToken() catch |err| {
                switch (err) {
                    lexerMod.LexerError.TokenTerminationAfterIdentifier => self.message = try std.fmt.allocPrint(allocator, "Identifier has to consist of letters and has to end with whitespace or the end of the string (token at position: {d}).", .{self.lexer.errorPosition}),
                    lexerMod.LexerError.TokenTerminationAfterQuotedString => self.message = try std.fmt.allocPrint(allocator, "Expected whitespace or end of the string after quoted string (token at position: {d}).", .{self.lexer.errorPosition}),
                    lexerMod.LexerError.UnclosedQuote => self.message = try std.fmt.allocPrint(allocator, "Quote unclosed (token at position: {d}).", .{self.lexer.errorPosition}),
                    lexerMod.LexerError.EscapingEnd => self.message = try std.fmt.allocPrint(allocator, "Escaping the end is not allowed (token at position: {d}).", .{self.lexer.errorPosition}),
                    lexerMod.LexerError.EscapingNonQuoteOrBackslashOrSpace => self.message = try std.fmt.allocPrint(allocator, "Only quotes backslashs or spaces can be escaped (token at position: {d}).", .{self.lexer.errorPosition}),
                }
                return err;
            };
            return token;
        }

        pub fn parse(self: *Self) !commandT {
            const token = try self.handleErrorNextToken();
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
            if (typeInfo == .@"struct") {
                return try self.parseStruct(T, token);
            }
            if (typeInfo == .@"union" and typeInfo.@"union".tag_type != null) {
                return try self.parseTaggedUnion(T, token);
            }
            if (typeInfo == .@"optional") {
                return try self.parseType(typeInfo.@"optional".child, token);
            }
            return self.parsePrimitiveType(T, token);
        }

        fn parseStruct(self: *Self, comptime T: type, token: lexerMod.Token) !T {
            const allocator = self.arena.allocator();
            if (token.type != lexerMod.TokenType.string or !std.mem.eql(u8, token.literal, comptime commandParserUtils.typeBaseName(T))) {

                self.message = "Command name at position {d} is invalid, expected ";
                self.message = try std.fmt.allocPrint(allocator, "Command name at position {d} is invalid, expected " ++ comptime commandParserUtils.typeBaseName(T) ++ ".", .{token.position});
                return ParserError.CommandNameInvalid;
            }

            const typeInfo = @typeInfo(T);
            var parsedStruct: T = undefined;
            var previousOption: ?[]const u8 = null;

            var arr: [typeInfo.@"struct".fields.len]bool = undefined;
            const found = &arr;
            @memset(found, false);

            while (true) {
                const tok = try self.handleErrorNextToken();
                if (tok.type == lexerMod.TokenType.eof) {
                    if (previousOption != null) {
                        self.message = "Expected value for option at position {d}, found end of string.";
                        self.message = try std.fmt.allocPrint(allocator, "Expected value for option at position {d}, found end of string.", .{tok.position});
                        return ParserError.OptionWithoutValue;
                    }
                    break;
                }

                try self.checkHelp(T, tok);

                if (tok.type == lexerMod.TokenType.string) {
                    if (previousOption) |prevOption| {
                        inline for (typeInfo.@"struct".fields) |field| {
                            if (std.mem.eql(u8, prevOption, field.name)) {
                                @field(parsedStruct, field.name) = try self.parseType(field.type, tok);
                            }
                        }
                        previousOption = null;
                        continue;
                    } else {
                        inline for (typeInfo.@"struct".fields) |field| {
                            const fieldTypeInfo = @typeInfo(field.type);
                            if (fieldTypeInfo == .@"union" and fieldTypeInfo.@"union".tag_type != null) {
                                @field(parsedStruct, field.name) = try self.parseTaggedUnion(field.type, tok);
                                break;
                            }
                        }
                        break;
                    }
                }

                if (previousOption != null) {
                    self.message = "Expected value for option at position {d}, found another option.";
                    self.message = try std.fmt.allocPrint(allocator, "Expected value for option at position {d}, found another option.", .{tok.position});
                    return ParserError.OptionWithoutValue;
                }

                var matched = false;
                inline for (0..typeInfo.@"struct".fields.len, typeInfo.@"struct".fields) |i, field| {
                    const isMatchingLongOption: bool = tok.type == lexerMod.TokenType.longOption and std.mem.eql(u8, tok.literal, field.name);
                    const isMatchingShortOption: bool = tok.type == lexerMod.TokenType.shortOption and tok.literal[0] == field.name[0];
                    if (isMatchingLongOption or isMatchingShortOption) {
                        matched = true;
                        if (found[i]) {
                            self.message = "Option at position {d} was found before multiple occurences of the same option are not allowed.";
                            self.message = try std.fmt.allocPrint(allocator, "Option at position {d} was found before multiple occurences of the same option are not allowed.", .{tok.position});
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
                    self.message = "Option at position {} not found to match any of the expected options.";
                    self.message = try std.fmt.allocPrint(allocator, "Option at position {} not found to match any of the expected options.", .{tok.position});
                    return ParserError.UnknownOption;
                }
            }

            inline for (0..typeInfo.@"struct".fields.len, typeInfo.@"struct".fields) |i, field| {
                if (!found[i]) {
                    if (@typeInfo(field.type) == .@"optional") {
                        @field(parsedStruct, field.name) = null;
                    } else if (field.defaultValue()) |default_value| {
                        const default_value_aligned: *align(field.alignment) const anyopaque = @alignCast(default_value);
                        @field(parsedStruct, field.name) = @as(*const field.type, @ptrCast(default_value_aligned)).*;
                    } else if (field.type == bool) {
                        @field(parsedStruct, field.name) = false;
                    } else if (@typeInfo(field.type) == .@"union" and @typeInfo(field.type).@"union".tag_type != null) {} else {
                        self.message = "Required option --" ++ field.name ++ " was not found.";
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
            inline for (typeInfo.@"union".fields) |field| {
                if (std.mem.eql(u8, token.literal, field.name)) {
                    if (@typeInfo(field.type) != .@"struct") {
                        @compileError("A subcommand has to be a struct.");
                    }

                    const parsedStruct = try self.parseStruct(field.type, token);
                    parsedUnion = @unionInit(T, field.name, parsedStruct);
                    matched = true;
                    break;
                }
            }
            if (!matched) {
                self.message = "Unknown command at position {d} {s}.";
                self.message = try std.fmt.allocPrint(self.arena.allocator(), "Unknown command at position {d} {s}.", .{ token.position, token.literal });
                return ParserError.UnknownSubcommand;
            }
            return parsedUnion;
        }

        fn parsePrimitiveType(self: *Self, comptime T: type, token: lexerMod.Token) !T {
            const typeInfo = @typeInfo(T);
            if (token.type == lexerMod.TokenType.string and typeInfo == .@"pointer" and
                typeInfo.@"pointer".size == .@"slice" and typeInfo.@"pointer".child == u8)
            {
                return try self.parseString(token.literal);
            }
            if (typeInfo == .@"float") {
                return try std.fmt.parseFloat(T, token.literal);
            }
            if (typeInfo == .@"int") {
                if (typeInfo.@"int".signedness == .signed) {
                    return try std.fmt.parseInt(T, token.literal, 0);
                }
                return try std.fmt.parseUnsigned(T, token.literal, 0);
            }
            unreachable;
        }

        fn parseString(self: *Self, string: []const u8) ![]u8 {
            const arenaAllocator = self.arena.allocator();
            var escapedString = try std.ArrayList(u8).initCapacity(arenaAllocator, 10);

            var escaped: bool = false;

            const str = if (string[0] == '"') string[1 .. string.len - 1] else string;
            for (str) |char| {
                if (escaped) {
                    try escapedString.append(arenaAllocator, char);
                    escaped = false;
                    continue;
                }

                if (char == '\\') {
                    escaped = true;
                    continue;
                }
                try escapedString.append(arenaAllocator, char);
            }

            return escapedString.items;
        }

        pub fn generateHelpMessage(comptime T: type) []const u8 {
            const typeInfo = @typeInfo(T);
            if (typeInfo == .@"struct") {
                return comptime Self.generateHelpMessageStruct(T);
            } else if (typeInfo == .@"union") {
                return "    " ++ comptime Self.generateHelpMessageTaggedUnion(T) ++ "\n";
            }
            unreachable;
        }

        fn generateHelpMessageStruct(comptime T: type) []const u8 {
            const typeInfo = @typeInfo(T);

            comptime var helpMessage: [typeInfo.@"struct".fields.len + 1][]const u8 = undefined;

            helpMessage[0] = "    -h, --help";

            comptime var maxLength = helpMessage[0].len;
            inline for (1..typeInfo.@"struct".fields.len + 1, typeInfo.@"struct".fields) |i, field| {
                helpMessage[i] = "    ";

                const fieldTypeInfo = @typeInfo(field.type);
                if (fieldTypeInfo == .@"union") {
                    if (fieldTypeInfo.@"union".tag_type == null) {
                        @compileError("Union has to be tagged.");
                    }
                    helpMessage[i] = "    " ++ comptime Self.generateHelpMessageTaggedUnion(field.type);
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

            inline for (1..typeInfo.@"struct".fields.len + 1, typeInfo.@"struct".fields) |i, field| {
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

            const tagTypeInfo = @typeInfo(@typeInfo(T).@"union".tag_type.?);
            if (tagTypeInfo != .@"enum") {
                @compileError("Union has to have enum as tag.");
            }
            inline for (tagTypeInfo.@"enum".fields[0 .. tagTypeInfo.@"enum".fields.len - 1]) |tagField| {
                message = message ++ tagField.name ++ ", ";
            }
            return message ++ tagTypeInfo.@"enum".fields[tagTypeInfo.@"enum".fields.len - 1].name;
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
