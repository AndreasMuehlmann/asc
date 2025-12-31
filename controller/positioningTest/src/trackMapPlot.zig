const Plot = @import("plot.zig").Plot;
const rl = @import("raylib");

pub const TrackMapPlot = struct {
    const Self = @This();

    plot: Plot,
    carSheet: rl.Texture2D,

    pub fn init(plot: Plot) !Self {
        return .{
            .plot = plot,
            .carSheet = try rl.loadTexture("/home/andi/programming/asc/controller/positioningTest/sprites/RacingCars_F1.png"),
        };
    }


    pub fn resize(self: *Self, windowWidth: f32, windowHeight: f32) void {
        self.plot.resize(windowWidth, windowHeight);
    }

    pub fn draw(self: Self) !void {
        try self.plot.draw();
    }

    pub fn drawCar(self: *Self, heading: f32, position: rl.Vector2) void {
        const spriteWidth = 39.0;
        const spriteHeight = 49.0;
       //const spriteWidth: f32 = @floatFromInt(self.carSheet.width);
       //const spriteHeight: f32 = @floatFromInt(self.carSheet.height);
        const src: rl.Rectangle = .{
            .x = 0,
            .y = 0,
            .width = spriteWidth,
            .height = spriteHeight,
        };

        const positionInPlot = self.plot.toGlobal(position);
        const dst: rl.Rectangle = .{
            .x = positionInPlot.x,
            .y = positionInPlot.y,
            .width = spriteWidth,
            .height = spriteHeight,
        };

        const origin: rl.Vector2 = .{
            .x = spriteWidth / 2.0,
            .y = 0.0,
        };

        rl.drawTexturePro(
            self.carSheet,
            src,
            dst,
            origin,
            heading - 90.0,
            rl.Color.white,
        );
    }

    pub fn addPoints(self: *Self, dataSetName: []const u8, points: []const rl.Vector2) !void {
        try self.plot.addPoints(dataSetName, points);
    }

    pub fn deinit(self: *Self) void {
        self.plot.deinit();
    }
};

