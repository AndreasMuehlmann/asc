const std = @import("std");
const lexerMod = @import("lexer.zig");

const ParserError = error{
    InfoNotSameLengthAsCommandFields,
    MultipleSameOption,
    UnknownOption,
    OptionWithoutValue,
    CommandNameInvalid,
};

pub const Info = struct {
    found: bool = false,
    description: []const u8,
};

pub fn CommandParser(comptime commandT: type) type {
    const commandTInfo = @typeInfo(commandT);
    if (commandTInfo != .Struct) {
        @compileError("Expected commandT to be a struct.");
    }

    return struct {
        allocator: std.mem.Allocator,
        lexer: lexerMod.Lexer,
        infos: []Info,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, command: []const u8, infos: []Info) !Self {
            if (commandTInfo.Struct.fields.len != infos.len) {
                return ParserError.InfoNotSameLengthAsCommandFields;
            }
            return .{ .allocator = allocator, .lexer = lexerMod.Lexer.init(command), .infos = infos };
        }

        fn parse(self: *Self) !commandT {
            const token = try self.lexer.nextToken();
            return try self.parseType(commandT, token);
        }

        fn parseType(self: *Self, comptime T: type, token: lexerMod.Token) !T {
            const typeInfo = @typeInfo(T);
            if (typeInfo == .Struct) {
                const typeName = @typeName(T);
                const optionalIndex = std.mem.lastIndexOfLinear(u8, typeName, ".");
                const typeBaseName = if (optionalIndex) |index| typeName[index + 1 ..] else typeName;
                if (token.type != lexerMod.TokenType.string or !std.mem.eql(u8, token.literal, typeBaseName)) {
                    return ParserError.CommandNameInvalid;
                }

                return try self.parseStruct(T);
            } else {
                return parsePrimitiveType(T, token);
            }
            return error.NotImplemented;
        }

        fn parseStruct(self: *Self, comptime T: type) !T {
            var parsedStruct: T = undefined;
            //if (!@hasField(T, "infos")) {
            //    @compileError("A command has to have an infos field.");
            //}
            //const infosTypeInfo = @typeInfo(@field(T, "infos"));
            //if (infosTypeInfo != .Pointer or infosTypeInfo.Pointer.size != .Slice or infosTypeInfo.Pointer.child != Info) {
            //    @compileError("A command has to have an infos field which has to be a slice of Info.");
            //}
            var previousOption: ?[]const u8 = null;
            while (true) {
                const token = try self.lexer.nextToken();
                if (token.type == lexerMod.TokenType.eof) {
                    break;
                }
                if (token.type == lexerMod.TokenType.string) {
                    if (previousOption) |prevOption| {
                        inline for (commandTInfo.Struct.fields) |field| {
                            if (std.mem.eql(u8, prevOption, field.name)) {
                                @field(parsedStruct, field.name) = try self.parseType(field.type, token);
                            }
                        }
                        previousOption = null;
                    } else {
                        continue;
                    }
                    continue;
                }
                if (token.type == lexerMod.TokenType.longOption) {
                    if (previousOption != null) {
                        return ParserError.OptionWithoutValue;
                    }
                    var matched = false;
                    inline for (0..commandTInfo.Struct.fields.len, commandTInfo.Struct.fields) |_, field| {
                        if (std.mem.eql(u8, token.literal, field.name)) {
                            matched = true;
                            //if (self.infos[i].found) {
                            //    return ParserError.MultipleSameOption;
                            //}
                            //self.infos[i].found = true;

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
            }
            return parsedStruct;
        }

        fn parsePrimitiveType(comptime T: type, token: lexerMod.Token) !T {
            const typeInfo = @typeInfo(T);
            if (typeInfo == .Pointer and typeInfo.Pointer.size == .Slice) {
                // allocate this string
                return token.literal;
            }
            return error.NotImplemented;
        }
    };
}

const testing = std.testing;

const set = struct {
    flag: bool = false,
    ssid: []const u8,
    password: []const u8,
    security: u8 = 2,
    optional: ?f32,
};

test "TestParser" {
    var infos = [_]Info{
        .{ .description = "A boolean flag" },
        .{ .description = "The ssid for the wlan" },
        .{ .description = "The password for the wlan" },
        .{ .description = "The security level used" },
        .{ .description = "An optional" },
    };
    var commandParser = try CommandParser(set).init(testing.allocator, "set --ssid SomeName --password 12345 --flag", &infos);
    const setCommand: set = try commandParser.parse();
    try testing.expectEqualStrings("SomeName", setCommand.ssid);
    try testing.expectEqualStrings("12345", setCommand.password);
    try testing.expect(setCommand.flag);
}
