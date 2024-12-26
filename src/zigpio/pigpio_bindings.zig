const std = @import("std");

pub const LibPigpio = struct {
    lib: *std.DynLib,
    gpio: struct {
        initialise: *const fn () callconv(.C) c_int,
        terminate: *const fn () callconv(.C) void,
        setMode: *const fn (gpio: c_uint, mode: c_uint) callconv(.C) c_int,
        getMode: *const fn (gpio: c_uint) callconv(.C) c_uint,
        setPullUpDown: *const fn (gpio: c_uint, pud: c_uint) callconv(.C) c_int,
        read: *const fn (gpio: c_uint) callconv(.C) c_int,
        write: *const fn (gpio: c_uint, value: c_int) callconv(.C) c_int,
    },

    // todo: implement spi
    spi: struct {
        open: *const fn (chan: c_uint, baud: c_uint, flags: c_uint) callconv(.C) c_int,
        close: *const fn (handle: c_int) callconv(.C) c_int,
        read: *const fn (handle: c_int, buffer: [*]c_char, count: c_uint) callconv(.C) c_int,
        write: *const fn (handle: c_int, buffer: [*]c_char, count: c_uint) callconv(.C) c_int,
        xfer: *const fn (handle: c_int, txbuf: [*]u8, rxbuf: [*]u8, count: c_uint) callconv(.C) c_int,
    },

    const Self = @This();

    pub fn init() !Self {
        var lib = std.DynLib.open("/lib/libpigpio.so.1") catch {
            std.debug.print("Failed to locate the libpigpio library at /lib/libpigpio.so.1\n", .{});
            return Error.LibraryLoadFailed;
        };
        errdefer lib.close();

        return Self{
            .lib = &lib,
            .gpio = .{
                .initialise = lib.lookup(*const fn () callconv(.C) c_int, "gpioInitialise") orelse return Error.SymbolNotFound,
                .terminate = lib.lookup(*const fn () callconv(.C) void, "gpioTerminate") orelse return Error.SymbolNotFound,
                .setMode = lib.lookup(*const fn (gpio: c_uint, mode: c_uint) callconv(.C) c_int, "gpioSetMode") orelse return Error.SymbolNotFound,
                .getMode = lib.lookup(*const fn (gpio: c_uint) callconv(.C) c_uint, "gpioGetMode") orelse return Error.SymbolNotFound,
                .setPullUpDown = lib.lookup(*const fn (gpio: c_uint, pud: c_uint) callconv(.C) c_int, "gpioSetPullUpDown") orelse return Error.SymbolNotFound,
                .read = lib.lookup(*const fn (gpio: c_uint) callconv(.C) c_int, "gpioRead") orelse return Error.SymbolNotFound,
                .write = lib.lookup(*const fn (gpio: c_uint, value: c_int) callconv(.C) c_int, "gpioWrite") orelse return Error.SymbolNotFound,
            },
            .spi = .{
                .open = lib.lookup(*const fn (chan: c_uint, baud: c_uint, flags: c_uint) callconv(.C) c_int, "spiOpen") orelse return Error.SymbolNotFound,
                .close = lib.lookup(*const fn (handle: c_int) callconv(.C) c_int, "spiClose") orelse return Error.SymbolNotFound,
                .read = lib.lookup(*const fn (handle: c_int, buffer: [*]c_char, count: c_uint) callconv(.C) c_int, "spiRead") orelse return Error.SymbolNotFound,
                .write = lib.lookup(*const fn (handle: c_int, buffer: [*]c_char, count: c_uint) callconv(.C) c_int, "spiWrite") orelse return Error.SymbolNotFound,
                .xfer = lib.lookup(*const fn (handle: c_int, txbuf: [*]u8, rxbuf: [*]u8, count: c_uint) callconv(.C) c_int, "spiXfer") orelse return Error.SymbolNotFound,
            },
        };
    }

    pub fn deinit(self: Self) void {
        self.lib.close();
    }

    pub const Error = error{
        LibraryLoadFailed,
        SymbolNotFound,
    };
};
