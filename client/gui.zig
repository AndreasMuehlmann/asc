const std = @import("std");

const sdl2 = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_render.h");
    @cInclude("SDL2/SDL_video.h");
    @cInclude("SDL2/SDL2_gfxPrimitives.h");
});

pub const Gui = struct {
    pub const GuiError = error{
        SDLInitialization,
        WindowCreation,
        RendererCreation,
        Quit,
    };

    const Self = @This();
    width: c_int,
    height: c_int,
    window: *sdl2.SDL_Window,
    renderer: *sdl2.SDL_Renderer,

    pub fn init() !Self {
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
        return .{ .width = windowWidth, .height = windowHeight, .window = windowOptional.?, .renderer = rendererOptional.? };
    }

    pub fn update(self: *Self) !void {
        var event: sdl2.SDL_Event = undefined;

        while (sdl2.SDL_PollEvent(&event) == 1) {
            if (event.type == sdl2.SDL_QUIT) {
                return GuiError.Quit;
            } else if (event.type == sdl2.SDL_WINDOWEVENT and event.window.event == sdl2.SDL_WINDOWEVENT_SIZE_CHANGED) {
                sdl2.SDL_GetWindowSize(self.window, &self.width, &self.height);
            }
        }

        _ = sdl2.SDL_SetRenderDrawColor(self.renderer, 255, 255, 255, 255);
        _ = sdl2.SDL_RenderClear(self.renderer);
        sdl2.SDL_RenderPresent(self.renderer);
    }

    pub fn deinit(self: Self) void {
        sdl2.SDL_DestroyRenderer(self.renderer);
        sdl2.SDL_DestroyWindow(self.window);
        sdl2.SDL_Quit();
    }
};
