const std = @import("std");

const rl = @import("raylib");

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

    const Self = @This();

    const marginText = 10.0;
    const consoleFontSize = 20.0;
    const lineSpacing = 4.0;
    const lineOffset = consoleFontSize + lineSpacing;
    const cursorWidth = 4.0;
    const spacing = 2.0;

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

            if (rl.isKeyPressed(rl.KeyboardKey.backspace)) {
                _ = self.leftOfCursor.pop();
            }

            if (rl.isKeyPressed(rl.KeyboardKey.left)) {
                const popped = self.leftOfCursor.pop();
                if (popped) |char| {
                    try self.rightOfCursor.insert(self.allocator, 0, char);
                }
            }

            if (rl.isKeyPressed(rl.KeyboardKey.right) and self.rightOfCursor.items.len > 0) {
                const removed = self.rightOfCursor.orderedRemove(0);
                try self.leftOfCursor.append(self.allocator, removed);
            }

            if (rl.isKeyPressed(rl.KeyboardKey.enter)) {
                try self.leftOfCursor.appendSlice(self.allocator, self.rightOfCursor.items);
                const command = try self.leftOfCursor.toOwnedSlice(self.allocator);
                try self.commands.append(self.allocator, command);

                self.leftOfCursor = try std.ArrayList(u8).initCapacity(self.allocator, 10);
                self.rightOfCursor.clearAndFree(self.allocator);
            }
        } else {
            rl.setMouseCursor(rl.MouseCursor.default);
        }

        const textBoxI32X: i32 = @intFromFloat(textBox.x);
        const textBoxI32Y: i32 = @intFromFloat(textBox.y);
        rl.drawRectangleRec(textBox, rl.Color.light_gray);
        if (mouseOnText) {
            rl.drawRectangleLines(textBoxI32X, textBoxI32Y, @intFromFloat(textBox.width), @intFromFloat(textBox.height), rl.Color.black);
        } else {
            rl.drawRectangleLines(textBoxI32X, textBoxI32Y, @intFromFloat(textBox.width), @intFromFloat(textBox.height), rl.Color.dark_gray);
        }
        _ = try self.drawCommand();
    }

    fn drawCommand(self: *Self) !f32 {
        const cursorPosition = try drawWrappedText(self, self.leftOfCursor.items, self.topLeftText);
        rl.drawRectangle(
            @intFromFloat(cursorPosition.x),
            @intFromFloat(cursorPosition.y),
            @intFromFloat(cursorWidth),
            @intFromFloat(consoleFontSize),
            rl.Color.white,
        );
        const endPosition = try drawWrappedText(self, self.rightOfCursor.items, rl.Vector2.init(cursorPosition.x + spacing, cursorPosition.y));
        return endPosition.y + lineOffset;
    }

    fn drawWrappedText(self: *Self, text: []const u8, startingPos: rl.Vector2) !rl.Vector2 {
        if (text.len == 0) {
            return startingPos;
        }
        var x = startingPos.x;
        var y = startingPos.y;
        var start: usize = 0;

        var current = try std.ArrayList(u8).initCapacity(self.allocator, 10);
        defer current.deinit(self.allocator);
        for (1..text.len + 1) |i| {
            current.clearRetainingCapacity();
            try current.appendSlice(self.allocator, text[start..i]);
            try current.append(self.allocator, 0);
            
            const textSize = rl.measureTextEx(try rl.getFontDefault(), current.items[0 .. current.items.len - 1 :0], consoleFontSize, spacing).x;
            if (textSize < self.sizeText.x + self.topLeftText.x - x) {
                continue;
            }
            _ = current.pop();
            _ = current.pop();
            try current.append(self.allocator, 0);

            rl.drawTextEx(
                try rl.getFontDefault(),
                current.items[0 .. current.items.len - 1 :0],
                rl.Vector2.init(x, y),
                consoleFontSize,
                spacing,
                rl.Color.black,
            );

            x = self.topLeftText.x;
            y += lineOffset;
            start = i - 1;
        }
        if (text.len - start != 0) {
            current.clearRetainingCapacity();
            try current.appendSlice(self.allocator, text[start..]);
            try current.append(self.allocator, 0);
            rl.drawTextEx(
                try rl.getFontDefault(),
                current.items[0 .. current.items.len - 1 :0],
                rl.Vector2.init(x, y),
                consoleFontSize,
                spacing,
                rl.Color.black,
            );
            const textSize: f32 = rl.measureTextEx(try rl.getFontDefault(), current.items[0 .. current.items.len - 1 :0], consoleFontSize, spacing).x;
            x += textSize;
        }
        return rl.Vector2.init(x, y);
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
    }
};
