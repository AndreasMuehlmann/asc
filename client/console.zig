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
    text: std.ArrayList(u8),
    command: ?[]u8,

    const Self = @This();

    const marginText = 10.0;
    const fontSize = 20.0;

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
            .text = try std.ArrayList(u8).initCapacity(allocator, 10),
            .command = null,
        };
        try self.text.append(self.allocator, '#');
        try self.text.append(self.allocator, ' ');
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
        rl.drawFPS(10, 10);
        const textBox = rl.Rectangle.init(self.topLeft.x, self.topLeft.y, self.size.x, self.size.y);

        const mouseOnText = rl.checkCollisionPointRec(rl.getMousePosition(), textBox);

        if (mouseOnText) {
            rl.setMouseCursor(rl.MouseCursor.ibeam);

            var key: i32 = rl.getCharPressed();
            while (key > 0) {
                if (key >= 32 and key <= 125) {
                    try self.text.append(self.allocator, @intCast(key));
                }

                key = rl.getCharPressed();
            }

            if (rl.isKeyPressed(rl.KeyboardKey.backspace)) {
                if (self.text.items.len > 2) {
                    _ = self.text.pop();
                }
            }

            if (rl.isKeyPressed(rl.KeyboardKey.enter)) {
                self.resetCommand();
                self.command = try self.text.toOwnedSlice(self.allocator);
                self.text = try std.ArrayList(u8).initCapacity(self.allocator, 10);
                try self.text.append(self.allocator, '#');
                try self.text.append(self.allocator, ' ');
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

        const marginI32: i32 = @intFromFloat(self.margin);
        try self.text.append(self.allocator, 0);
        rl.drawText(self.text.items[0 .. self.text.items.len - 1 :0], textBoxI32X + marginI32, textBoxI32Y + marginI32, fontSize, rl.Color.black);
        _ = self.text.pop();
    }

    pub fn getCommand(self: Self) ?[]const u8 {
        if (self.command) |command| {
            return command[2..];
        }
        return null;
    }

    pub fn resetCommand(self: *Self) void {
        if (self.command) |command| {
            self.allocator.free(command);
            self.command = null;
        }
    }

    pub fn deinit(self: *Self) void {
        self.text.deinit(self.allocator);
        if (self.command) |command| {
            self.allocator.free(command);
        }
    }
};
