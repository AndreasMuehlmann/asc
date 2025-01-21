const std = @import("std");

const sdl2 = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_render.h");
    @cInclude("SDL2/SDL_video.h");
    @cInclude("SDL2/SDL2_gfxPrimitives.h");
});

pub const Vec2D = struct {
    x: f64,
    y: f64,
};

const RGBA = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

const DataSet = struct {
    points: std.ArrayList(Vec2D),
    color: RGBA,
    name: []const u8,
    lineWidth: u8,
};

const Plot = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    topLeft: Vec2D,
    size: Vec2D,
    minCoord: Vec2D,
    maxCoord: Vec2D,
    scaling: Vec2D,
    origin: Vec2D,
    dataSets: []DataSet,
    color: RGBA,

    renderer: *sdl2.SDL_Renderer,

    const Self = @This();
    const lineThickness: u8 = 3;

    pub fn init(allocator: std.mem.Allocator, name: []const u8, topLeft: Vec2D, size: Vec2D, margin: f64, minCoord: Vec2D, maxCoord: Vec2D, renderer: *sdl2.SDL_Renderer, dataSets: []DataSet, color: RGBA) Self {
        var self: Self = .{
            .allocator = allocator,
            .name = name,
            .topLeft = topLeft,
            .size = size,
            .minCoord = minCoord,
            .maxCoord = maxCoord,
            .scaling = .{ .x = 0, .y = 0 },
            .origin = .{ .x = 0, .y = 0 },
            .dataSets = dataSets,
            .renderer = renderer,
            .color = color,
        };
        self.resize(topLeft, size, margin, minCoord, maxCoord);
        return self;
    }

    pub fn resize(self: *Self, topLeft: Vec2D, size: Vec2D, margin: f64, minCoord: Vec2D, maxCoord: Vec2D) void {
        self.topLeft = .{ .x = topLeft.x + margin, .y = topLeft.y + margin };
        self.size = .{ .x = size.x - 2 * margin, .y = size.y - 2 * margin };
        self.minCoord = minCoord;
        self.minCoord = maxCoord;
        self.scaling = .{ .x = self.size.x / (self.maxCoord.x - self.minCoord.x), .y = self.size.y / (self.maxCoord.y - self.minCoord.y) };
        self.origin = .{ .x = self.topLeft.x + self.size.x * @abs(self.minCoord.x) / (self.maxCoord.x - self.minCoord.x), .y = self.topLeft.y + self.size.y * @abs(self.maxCoord.y) / (self.maxCoord.y - self.minCoord.y) };
    }

    fn toGlobal(self: Self, point: Vec2D) Vec2D {
        return .{
            .x = self.origin.x + point.x * self.scaling.x,
            .y = self.origin.y - point.y * self.scaling.y,
        };
    }

    pub fn draw(self: Self) void {
        for (self.dataSets) |dataSet| {
            //self.drawPoints(dataSet);
            self.drawLines(dataSet);
        }
        _ = sdl2.thickLineRGBA(self.renderer, @intFromFloat(self.topLeft.x), @intFromFloat(self.topLeft.y + self.size.y), @intFromFloat(self.topLeft.x + self.size.x), @intFromFloat(self.topLeft.y + self.size.y), lineThickness, self.color.r, self.color.g, self.color.b, self.color.a);
        _ = sdl2.thickLineRGBA(self.renderer, @intFromFloat(self.topLeft.x), @intFromFloat(self.topLeft.y + self.size.y), @intFromFloat(self.topLeft.x), @intFromFloat(self.topLeft.y), lineThickness, self.color.r, self.color.g, self.color.b, self.color.a);
    }

    fn drawPoints(self: Self, dataSet: DataSet) void {
        for (dataSet.points.items) |point| {
            const globalPoint = self.toGlobal(point);
            _ = sdl2.filledCircleRGBA(self.renderer, @intFromFloat(globalPoint.x), @intFromFloat(globalPoint.y), 2, dataSet.color.r, dataSet.color.g, dataSet.color.b, dataSet.color.a);
        }
    }

    fn drawLines(self: Self, dataSet: DataSet) void {
        if (dataSet.points.items.len == 0) {
            return;
        }
        var prevPoint = self.toGlobal(dataSet.points.items[0]);
        for (1..dataSet.points.items.len) |i| {
            const nextPoint = self.toGlobal(dataSet.points.items[i]);
            _ = sdl2.thickLineRGBA(self.renderer, @intFromFloat(prevPoint.x), @intFromFloat(prevPoint.y), @intFromFloat(nextPoint.x), @intFromFloat(nextPoint.y), dataSet.lineWidth, dataSet.color.r, dataSet.color.g, dataSet.color.b, dataSet.color.a);
            prevPoint = nextPoint;
        }
    }

    pub fn addPoints(self: *Self, dataSetName: []const u8, points: []const Vec2D) !void {
        for (0..self.dataSets.len) |i| {
            if (std.mem.eql(u8, dataSetName, self.dataSets[i].name)) {
                try self.dataSets[i].points.appendSlice(points);
                break;
            }
        }
    }

    pub fn deinit(self: Self) void {
        for (self.dataSets) |dataSet| {
            dataSet.points.deinit();
        }
    }
};

pub const Gui = struct {
    pub const GuiError = error{
        SDLInitialization,
        WindowCreation,
        RendererCreation,
        Quit,
    };

    const Self = @This();

    allocator: std.mem.Allocator,
    width: c_int,
    height: c_int,
    plots: []Plot,
    window: *sdl2.SDL_Window,
    renderer: *sdl2.SDL_Renderer,

    pub fn init(allocator: std.mem.Allocator) !Self {
        if (sdl2.SDL_Init(sdl2.SDL_INIT_VIDEO) < 0) {
            std.log.err("Could not initialize sdl2: {s}\n", .{sdl2.SDL_GetError()});
            return GuiError.SDLInitialization;
        }
        const windowWidth: c_int = 1960;
        const windowHeight: c_int = 1680;

        const windowOptional: ?*sdl2.SDL_Window = sdl2.SDL_CreateWindow("asc", sdl2.SDL_WINDOWPOS_UNDEFINED, sdl2.SDL_WINDOWPOS_UNDEFINED, windowWidth, windowHeight, sdl2.SDL_WINDOW_SHOWN | sdl2.SDL_WINDOW_MAXIMIZED | sdl2.SDL_WINDOW_RESIZABLE);
        if (windowOptional == null) {
            std.log.err("Could not create window: {s}\n", .{sdl2.SDL_GetError()});
            return GuiError.WindowCreation;
        }

        const rendererOptional: ?*sdl2.SDL_Renderer = sdl2.SDL_CreateRenderer(windowOptional, -1, sdl2.SDL_RENDERER_ACCELERATED);
        if (rendererOptional == null) {
            std.log.err("Renderer could not be created! SDL Error: {s}\n", .{sdl2.SDL_GetError()});
            sdl2.SDL_DestroyWindow(windowOptional);
            sdl2.SDL_Quit();
            return GuiError.RendererCreation;
        }
        var dataSets = try allocator.alloc(DataSet, 1);
        dataSets[0] = .{ .points = std.ArrayList(Vec2D).init(allocator), .name = "Heading", .color = .{ .r = 128, .g = 0, .b = 0, .a = 255 }, .lineWidth = 3 };

        var plots = try allocator.alloc(Plot, 1);
        plots[0] = Plot.init(allocator, "Orientation", .{ .x = 0.0, .y = 0.0 }, .{ .x = windowWidth, .y = windowHeight }, 20.0, .{ .x = 0.0, .y = 0.0 }, .{ .x = 100000.0, .y = 360.0 }, rendererOptional.?, dataSets, .{ .r = 0, .g = 0, .b = 0, .a = 255 });
        return .{ .allocator = allocator, .width = windowWidth, .height = windowHeight, .window = windowOptional.?, .renderer = rendererOptional.?, .plots = plots };
    }

    pub fn update(self: *Self) !void {
        var event: sdl2.SDL_Event = undefined;

        while (sdl2.SDL_PollEvent(&event) == 1) {
            if (event.type == sdl2.SDL_QUIT) {
                return GuiError.Quit;
            } else if (event.type == sdl2.SDL_WINDOWEVENT and event.window.event == sdl2.SDL_WINDOWEVENT_SIZE_CHANGED) {
                sdl2.SDL_GetWindowSize(self.window, &self.width, &self.height);
                for (0..self.plots.len) |i| {
                    const widthF64: f64 = @floatFromInt(self.width);
                    const heightF64: f64 = @floatFromInt(self.height);
                    self.plots[i].resize(.{ .x = 0.0, .y = 0.0 }, .{ .x = widthF64, .y = heightF64 }, 20.0, .{ .x = -10.0, .y = -10.0 }, .{ .x = 10.0, .y = 10.0 });
                }
            }
        }

        _ = sdl2.SDL_SetRenderDrawColor(self.renderer, 255, 255, 255, 255);
        _ = sdl2.SDL_RenderClear(self.renderer);

        for (self.plots) |plot| {
            plot.draw();
        }

        sdl2.SDL_RenderPresent(self.renderer);
    }

    pub fn addPoints(self: *Self, plotName: []const u8, dataSetName: []const u8, points: []const Vec2D) !void {
        for (0..self.plots.len) |i| {
            if (std.mem.eql(u8, plotName, self.plots[i].name)) {
                try self.plots[i].addPoints(dataSetName, points);
                break;
            }
        }
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.plots);
        sdl2.SDL_DestroyRenderer(self.renderer);
        sdl2.SDL_DestroyWindow(self.window);
        sdl2.SDL_Quit();
    }
};
