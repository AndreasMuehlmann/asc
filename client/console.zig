const std = @import("std");

const rl = @import("raylib");

pub const KeyTrigger = struct {
    const Self = @This();

    const ticksToRepetitionState: u32 = 30;
    const ticksBetweenRepetitions: u32 = 3;

    key: rl.KeyboardKey,
    ticksSincePressed: u32,

    pub fn init(key: rl.KeyboardKey) Self {
        return .{
            .key = key,
            .ticksSincePressed = 0,
        };
    }

    pub fn trigger(self: *Self) bool {
        if (!rl.isKeyDown(self.key)) {
            self.ticksSincePressed = 0;
            return false;
        }
        self.ticksSincePressed += 1;
        if (self.ticksSincePressed == 1) {
            return true;
        }
        if (self.ticksSincePressed >= ticksToRepetitionState) {
            if (self.ticksSincePressed >= ticksToRepetitionState + ticksBetweenRepetitions) {
                self.ticksSincePressed = ticksToRepetitionState;
            }
            return self.ticksSincePressed == ticksToRepetitionState;
        }
        return false;
    }
};

pub const Console = struct {
    allocator: std.mem.Allocator,
    relativeTopLeft: rl.Vector2,
    relativeSize: rl.Vector2,
    topLeft: rl.Vector2,
    topLeftText: rl.Vector2,
    size: rl.Vector2,
    sizeText: rl.Vector2,
    margin: f32,
    leftOfCursor: std.ArrayList(u8),
    rightOfCursor: std.ArrayList(u8),
    commands: std.ArrayList([]const u8),
    toFetchCommand: usize,
    historyIndex: usize,
    leftTrigger: KeyTrigger,
    rightTrigger: KeyTrigger,
    upTrigger: KeyTrigger,
    downTrigger: KeyTrigger,
    backspaceTrigger: KeyTrigger,
    output: std.ArrayList(u8),
    lines: [][:0]u8,
    font: rl.Font,

    const Self = @This();

    const marginText = 10.0;
    const consoleFontSize = 20.0;
    const lineSpacing = 4.0;
    const lineOffset: f32 = consoleFontSize + lineSpacing;
    const cursorWidth = 4.0;
    const consoleSpacing = 2.0;
    const maxOutputSize: usize = 10000;

    pub fn init(allocator: std.mem.Allocator, relativeTopLeft: rl.Vector2, relativeSize: rl.Vector2, margin: f32, windowWidth: f32, windowHeight: f32) !Self {
        var self: Self = .{
            .allocator = allocator,
            .relativeTopLeft = relativeTopLeft,
            .relativeSize = relativeSize,
            .topLeft = rl.Vector2.zero(),
            .topLeftText = rl.Vector2.zero(),
            .size = rl.Vector2.zero(),
            .sizeText = rl.Vector2.zero(),
            .margin = margin,
            .leftOfCursor = try std.ArrayList(u8).initCapacity(allocator, 10),
            .rightOfCursor = try std.ArrayList(u8).initCapacity(allocator, 10),
            .commands = try std.ArrayList([]const u8).initCapacity(allocator, 10),
            .toFetchCommand = 0,
            .historyIndex = 0,
            .leftTrigger = KeyTrigger.init(rl.KeyboardKey.left),
            .rightTrigger = KeyTrigger.init(rl.KeyboardKey.right),
            .downTrigger = KeyTrigger.init(rl.KeyboardKey.down),
            .upTrigger = KeyTrigger.init(rl.KeyboardKey.up),
            .backspaceTrigger = KeyTrigger.init(rl.KeyboardKey.backspace),
            .output = try std.ArrayList(u8).initCapacity(allocator, 10),
            .lines = &.{},
            .font = try rl.getFontDefault(),
        };
        self.resize(windowWidth, windowHeight);
        return self;
    }

    pub fn resize(self: *Self, windowWidth: f32, windowHeight: f32) void {
        self.topLeft = rl.Vector2.init(windowWidth, windowHeight).multiply(self.relativeTopLeft).addValue(self.margin);
        self.topLeftText = rl.Vector2.init(self.topLeft.x + marginText, self.topLeft.y + marginText);
        self.size = rl.Vector2.init(windowWidth, windowHeight).multiply(self.relativeSize).addValue(-2 * self.margin);
        self.sizeText = rl.Vector2.init(self.size.x - 2 * marginText, self.size.y - 2 * marginText);
    }

    pub fn update(self: *Self) !void {
        const textBox = rl.Rectangle.init(self.topLeft.x, self.topLeft.y, self.size.x, self.size.y);

        const mouseOnText = rl.checkCollisionPointRec(rl.getMousePosition(), textBox);

        if (mouseOnText) {
            rl.setMouseCursor(rl.MouseCursor.ibeam);

            var key: i32 = rl.getCharPressed();
            while (key > 0) {
                if (key >= 32 and key <= 125) {
                    try self.leftOfCursor.append(self.allocator, @intCast(key));
                }

                key = rl.getCharPressed();
            }

            const ctrlHeld = rl.isKeyDown(rl.KeyboardKey.right_control) or rl.isKeyDown(rl.KeyboardKey.left_control);
            if (ctrlHeld and self.backspaceTrigger.trigger()) {
                while (self.leftOfCursor.items.len > 0 and isWhitespace(self.leftOfCursor.items[self.leftOfCursor.items.len - 1])) {
                    _ = self.leftOfCursor.pop();
                }
                while (self.leftOfCursor.items.len > 0 and !isWhitespace(self.leftOfCursor.items[self.leftOfCursor.items.len - 1])) {
                    _ = self.leftOfCursor.pop();
                }
            } else if (self.backspaceTrigger.trigger()) {
                _ = self.leftOfCursor.pop();
            }

            if (ctrlHeld and self.leftTrigger.trigger()) {
                while (self.leftOfCursor.items.len > 0 and isWhitespace(self.leftOfCursor.items[self.leftOfCursor.items.len - 1])) {
                    try self.moveLeft();
                }
                while (self.leftOfCursor.items.len > 0 and !isWhitespace(self.leftOfCursor.items[self.leftOfCursor.items.len - 1])) {
                    try self.moveLeft();
                }
            } else if (self.leftTrigger.trigger()) {
                try self.moveLeft();
            }


            if (ctrlHeld and self.rightTrigger.trigger() and self.rightOfCursor.items.len > 0) {
                while (self.rightOfCursor.items.len > 0 and isWhitespace(self.rightOfCursor.items[self.rightOfCursor.items.len - 1])) {
                    try self.moveRight();
                }
                while (self.rightOfCursor.items.len > 0 and !isWhitespace(self.rightOfCursor.items[self.rightOfCursor.items.len - 1])) {
                    try self.moveRight();
                }
            } else if (self.rightTrigger.trigger() and self.rightOfCursor.items.len > 0) {
                try self.moveRight();
            }

            if (self.upTrigger.trigger() and self.historyIndex != 0) {
                self.historyIndex -= 1;
                self.leftOfCursor.clearAndFree(self.allocator);
                try self.leftOfCursor.appendSlice(self.allocator, self.commands.items[self.historyIndex]);
                self.rightOfCursor.clearAndFree(self.allocator);
            }

            if (self.downTrigger.trigger() and self.historyIndex < self.commands.items.len - 1) {
                self.historyIndex += 1;
                self.leftOfCursor.clearAndFree(self.allocator);
                try self.leftOfCursor.appendSlice(self.allocator, self.commands.items[self.historyIndex]);
                self.rightOfCursor.clearAndFree(self.allocator);
            }

            if (rl.isKeyPressed(rl.KeyboardKey.enter)) {
                try self.leftOfCursor.appendSlice(self.allocator, self.rightOfCursor.items);
                const command = try self.leftOfCursor.toOwnedSlice(self.allocator);
                try self.commands.append(self.allocator, command);
                self.historyIndex = self.commands.items.len;

                self.leftOfCursor = try std.ArrayList(u8).initCapacity(self.allocator, 10);
                self.rightOfCursor.clearAndFree(self.allocator);
            }
        } else {
            rl.setMouseCursor(rl.MouseCursor.default);
        }

        rl.drawRectangleRec(textBox, rl.Color.ray_white);

        const seperatorY = @max(try self.drawCommand(), self.topLeftText.y + lineOffset);
        const color = if (mouseOnText) rl.Color.black else rl.Color.dark_gray;
        rl.drawLineEx(self.topLeft, rl.Vector2.init(self.topLeft.x + self.size.x, self.topLeft.y), 1.0, color);
        rl.drawLineEx(self.topLeft, rl.Vector2.init(self.topLeft.x, self.topLeft.y + self.size.y), 1.0, color);
        rl.drawLineEx(rl.Vector2.init(self.topLeft.x, seperatorY), rl.Vector2.init(self.topLeft.x + self.size.x, seperatorY), 1.0, color);

        self.drawBufferWithLineBounds(self.lines, rl.Vector2.init(self.topLeftText.x, seperatorY + lineOffset));
    }

    fn isWhitespace(char: u8) bool {
        return char == '\n' or char == '\t' or char == ' ';
    }

    fn moveLeft(self: *Self) !void {
        const popped = self.leftOfCursor.pop();
        if (popped) |char| {
            try self.rightOfCursor.insert(self.allocator, 0, char);
        }
    }

    fn moveRight(self: *Self) !void {
        const removed = self.rightOfCursor.orderedRemove(0);
        try self.leftOfCursor.append(self.allocator, removed);
    }

    pub fn writeToOutput(self: *Self, text: []const u8) !void {
        if (self.output.items.len + text.len > maxOutputSize) {
            try self.output.replaceRange(self.allocator, 0, self.output.items.len + text.len - maxOutputSize, &.{});
        }
        try self.output.appendSlice(self.allocator, text);
        for (self.lines) |line| {
            self.allocator.free(line);
        }
        self.allocator.free(self.lines);
        self.lines = try textToLines(self.allocator, self.output.items, self.font, consoleFontSize, consoleSpacing, self.sizeText.x);
    }

    fn drawCommand(self: *Self) !f32 {
        var commandLine = try std.ArrayList(u8).initCapacity(self.allocator, 2 + self.leftOfCursor.items.len + self.rightOfCursor.items.len);
        defer commandLine.deinit(self.allocator);
        try commandLine.appendSlice(self.allocator, "# ");
        try commandLine.appendSlice(self.allocator, self.leftOfCursor.items);
        const leftOfCursorLines = try textToLines(self.allocator, commandLine.items, self.font, consoleFontSize, consoleSpacing, self.sizeText.x);
        const lastLine = if (leftOfCursorLines.len == 0) "" else leftOfCursorLines[leftOfCursorLines.len - 1];
        var lastLineLength: f32 = 0.0; 
        for (lastLine) |char| {
            lastLineLength += glyphAdvance(self.font, consoleFontSize, consoleSpacing, char);
        }
        const lineCountLeftOfCursor: f32 = @floatFromInt(leftOfCursorLines.len);
        const cursorPosition = self.topLeftText.add(rl.Vector2.init(lastLineLength, (@max(1, lineCountLeftOfCursor) - 1) * lineOffset));
        for (leftOfCursorLines) |line| {
            self.allocator.free(line);
        }
        self.allocator.free(leftOfCursorLines);

        try commandLine.appendSlice(self.allocator, self.rightOfCursor.items);

        const lines = try textToLines(self.allocator, commandLine.items, self.font, consoleFontSize, consoleSpacing, self.sizeText.x);
        const lineCount: f32 = @floatFromInt(lines.len);
        const seperatorY = self.topLeftText.y + @max(1, lineCount) * lineOffset;

        rl.drawRectangle(
            @intFromFloat(cursorPosition.x),
            @intFromFloat(cursorPosition.y),
            @intFromFloat(cursorWidth),
            @intFromFloat(consoleFontSize),
            rl.Color.light_gray,
        );
        self.drawBufferWithLineBounds(lines, self.topLeftText);

        for (lines) |line| {
            self.allocator.free(line);
        }
        self.allocator.free(lines);
        return seperatorY;
    }

    fn glyphAdvance(font: rl.Font, fontSize: f32, spacing: f32, char: u8) f32 {
        const g = rl.getGlyphInfo(font, @intCast(char));
        const atlasRec = rl.getGlyphAtlasRec(font, @intCast(char));
        const advanceXF32: f32 = @floatFromInt(g.advanceX);
        const baseSizeF32: f32 = @floatFromInt(font.baseSize);
        const offsetXF32: f32 = @floatFromInt(g.offsetX);
        const scale = fontSize / baseSizeF32;
        return if (g.advanceX > 0) advanceXF32 * scale + spacing else (atlasRec.width + offsetXF32) * scale + spacing;
    }

    fn textToLines(allocator: std.mem.Allocator, text: []const u8, font: rl.Font, fontSize: f32, spacing: f32, maxWidth: f32) ![][:0]u8 {
        if (text.len == 0) {
            return &.{};
        }

        var start: usize = 0;
        var lines = try std.ArrayList([:0]u8).initCapacity(allocator, 10);
        var lineWidth: f32 = 0.0;
        for (0..text.len) |i| {
            if (text[i] == '\n') {
                const line = try allocator.dupeZ(u8, text[start..i]);
                try lines.append(allocator, line);
                start = i + 1;
                lineWidth = 0.0;
                continue;
            }
            const charWidth = glyphAdvance(font, fontSize, spacing, text[i]);
            lineWidth += charWidth;
            if (lineWidth < maxWidth) {
                continue;
            }

            const line = try allocator.dupeZ(u8, text[start..i]);
            try lines.append(allocator, line);

            start = i;
            lineWidth = charWidth;
        }
        if (text.len - start != 0) {
            const line = try allocator.dupeZ(u8, text[start..]);
            try lines.append(allocator, line);
        }
        return try lines.toOwnedSlice(allocator);
    }

    fn drawBufferWithLineBounds(self: *Self, lines: [][:0]u8, startingPos: rl.Vector2) void {
        if (lines.len == 0) {
            return;
        }
        for (lines, 0..) |line, i| {
            const iF32: f32 = @floatFromInt(i);
            rl.drawTextEx(
                self.font,
                line,
                rl.Vector2.init(startingPos.x, startingPos.y + iF32 * lineOffset),
                consoleFontSize,
                consoleSpacing,
                rl.Color.black,
            );
        }
    }

    pub fn getCommand(self: *Self) ?[]const u8 {
        if (self.commands.items.len > self.toFetchCommand) {
            self.toFetchCommand += 1;
            return self.commands.items[self.toFetchCommand - 1];
        }
        return null;
    }

    pub fn deinit(self: *Self) void {
        self.leftOfCursor.deinit(self.allocator);
        self.rightOfCursor.deinit(self.allocator);
        for (self.commands.items) |command| {
            self.allocator.free(command);
        }
        self.commands.deinit(self.allocator);
        for (self.lines) |line| {
            self.allocator.free(line);
        }
        self.allocator.free(self.lines);
        self.output.deinit(self.allocator);
    }
};
