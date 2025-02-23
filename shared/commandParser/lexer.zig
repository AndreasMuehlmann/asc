const std = @import("std");

const LexerError = error{
    TokenTerminationAfterIdentifier,
    TokenTerminationAfterQuotedString,
    UnclosedQuote,
    UnexpectedCharacter,
    EscapingEnd,
    EscapingNonQuoteOrBackslashOrSpace,
};

pub const TokenType = enum {
    shortOption,
    longOption,
    string,
    eof,
};

pub const Token = struct {
    type: TokenType,
    literal: []const u8,
};

pub const Lexer = struct {
    command: []const u8,
    position: usize,
    readPosition: usize,
    char: u8,

    const Self = @This();

    pub fn init(command: []const u8) Self {
        var self: Self = .{ .command = command, .position = 0, .readPosition = 0, .char = 0 };
        self.char = self.readChar();
        return self;
    }

    pub fn nextToken(self: *Self) !Token {
        self.skipWhiteSpace();
        const position = self.position;
        switch (self.char) {
            '-' => {
                const c = self.peekChar();
                _ = self.readChar();
                if (c == '-') {
                    const ch = self.peekChar();
                    _ = self.readChar();
                    if (Self.isLetter(ch)) {
                        return .{ .type = TokenType.longOption, .literal = try self.readIdentifier() };
                    }
                } else if (Self.isLetter(c)) {
                    if (Self.isTokenTermination(self.peekChar())) {
                        _ = self.readChar();
                        return .{ .type = TokenType.shortOption, .literal = self.command[self.position - 1 .. self.position] };
                    }
                } else {
                    _ = self.goto(position);
                    return .{ .type = TokenType.string, .literal = try self.readString() };
                }
                unreachable;
            },
            0 => return .{ .type = TokenType.eof, .literal = "" },
            else => {
                return .{ .type = TokenType.string, .literal = try self.readString() };
            },
        }
        unreachable;
    }

    fn readChar(self: *Self) u8 {
        if (self.readPosition >= self.command.len) {
            self.char = 0;
        } else {
            self.char = self.command[self.readPosition];
        }
        self.position = self.readPosition;
        self.readPosition += 1;
        return self.char;
    }

    fn peekChar(self: *Self) u8 {
        if (self.readPosition >= self.command.len) {
            return 0;
        } else {
            return self.command[self.readPosition];
        }
    }

    fn isTokenTermination(char: u8) bool {
        return char == ' ' or char == '\t' or char == '\n' or char == 0;
    }

    fn isWhiteSpace(char: u8) bool {
        return char == ' ' or char == '\t' or char == '\n';
    }

    fn skipWhiteSpace(self: *Self) void {
        while (isWhiteSpace(self.char)) {
            _ = self.readChar();
        }
    }

    fn readIdentifier(self: *Self) ![]const u8 {
        const position = self.position;
        while (Self.isLetter(self.char)) {
            _ = self.readChar();
        }
        if (!Self.isTokenTermination(self.char)) {
            return LexerError.TokenTerminationAfterIdentifier;
        }
        return self.command[position..self.position];
    }

    fn isLetter(char: u8) bool {
        return ('a' <= char and char <= 'z') or ('A' <= char and char <= 'Z') and char == '_';
    }

    fn readString(self: *Self) ![]const u8 {
        const position = self.position;
        var escaped: bool = false;
        const quoted: bool = self.char == '"';
        while (true) {
            const char = self.readChar();
            if (quoted and char == 0) {
                return LexerError.UnclosedQuote;
            }
            if (escaped and char == 0) {
                return LexerError.EscapingEnd;
            }

            if (escaped and (char != '"' and char != '\\' and char != ' ')) {
                return LexerError.EscapingNonQuoteOrBackslashOrSpace;
            }
            if (escaped) {
                escaped = false;
                continue;
            }

            if (quoted and char == '"') {
                if (!Self.isTokenTermination(self.readChar())) {
                    return LexerError.TokenTerminationAfterQuotedString;
                }
                return self.command[position..self.position];
            }

            if (char == '\\') {
                escaped = true;
                continue;
            }

            if (quoted) {
                continue;
            }

            if (Self.isTokenTermination(char)) {
                return self.command[position..self.position];
            }
        }
        unreachable;
    }

    fn goto(self: *Self, position: usize) u8 {
        self.position = position;
        self.readPosition = position + 1;
        self.char = self.command[position];
        return self.char;
    }
};

test "TestNextToken" {
    const command = "prog --op -123.0 -h \"quoted\" \"\" \"\\\\\\\"";
    var lexer = Lexer.init(command);
    {
        const token = try lexer.nextToken();
        try std.testing.expectEqual(token.type, TokenType.string);
        try std.testing.expectEqualStrings("prog", token.literal);
    }
    {
        const token = try lexer.nextToken();
        try std.testing.expectEqual(token.type, TokenType.longOption);
        try std.testing.expectEqualStrings("op", token.literal);
    }
    {
        const token = try lexer.nextToken();
        try std.testing.expectEqual(token.type, TokenType.string);
        try std.testing.expectEqualStrings("-123.0", token.literal);
    }
    {
        const token = try lexer.nextToken();
        try std.testing.expectEqual(token.type, TokenType.shortOption);
        try std.testing.expectEqualStrings("h", token.literal);
    }
    {
        const token = try lexer.nextToken();
        try std.testing.expectEqual(token.type, TokenType.string);
        try std.testing.expectEqualStrings("\"quoted\"", token.literal);
    }
    {
        const token = try lexer.nextToken();
        try std.testing.expectEqual(token.type, TokenType.string);
        try std.testing.expectEqualStrings("\"\"", token.literal);
    }
    try std.testing.expectError(LexerError.UnclosedQuote, lexer.nextToken());
}
