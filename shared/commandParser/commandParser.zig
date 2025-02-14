const std = @import("std");
const lexerMod = @import("lexer.zig");

pub fn CommandParser(comptime commandT: type) type {
    const typeInfo = @typeInfo(commandT);
    if (typeInfo != .Union or typeInfo.Union.tag_type == null) {
        @compileError("commandT has to be a tagged Union.");
    }
    const commandEnumT: type = typeInfo.Union.tag_type.?;
    _ = commandEnumT;

    return struct {
        allocator: std.mem.Allocator,
        lexer: lexerMod.Lexer,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, command: []const u8) Self {
            return .{ .allocator = allocator, .lexer = lexerMod.Lexer.init(command) };
        }

        pub fn parse(self: *Self) commandT {
            return self.lexer.nextToken();
        }
    };
}

test "TestTesting" {
    _ = lexerMod.Lexer.init("hello");
}
