const std = @import("std");
const LibPigpio = @import("pigpio_bindings.zig").LibPigpio;

// GPIO is a wrapper around the raw pigpio library GPU functions
// making the interface more idiomatic for zig
pub const GPIO = struct {
    lib: LibPigpio,

    const Self = @This();

    pub fn init() !Self {
        // assert that the library is loaded at runtime
        if (@inComptime()) {
            @compileError("GPIO.init() must be called at runtime to dynamically load the pigpio library");
        }

        // init the c library itself
        var lib = LibPigpio.init() catch |err| {
            std.debug.print("Failed to initialize pigpio: {}\n", .{err});
            return err;
        };
        errdefer lib.deinit();

        // since we're in the GPIO module, the gpio module must also be initialized
        const result = lib.gpio.initialise();
        if (result < 0) {
            std.debug.print("Failed to initialize pigpio: {}\n", .{LibErrorCode.from_c_int(result)});
            return error.FailedToInitialize;
        }

        return Self{ .lib = lib };
    }

    pub fn deinit(self: Self) void {
        self.lib.gpio.terminate();
        self.lib.deinit();
    }

    pub fn setMode(self: Self, pin: Pin, mode: Mode) !void {
        const result = self.lib.gpio.setMode(
            @intFromEnum(pin),
            @intFromEnum(mode),
        );
        if (result < 0) {
            const err = LibErrorCode.from_c_int(result);
            switch (err) {
                .PI_BAD_GPIO => unreachable, // PIN enum already checked
                .PI_BAD_MODE => unreachable, // Mode enum already checked
                else => return Error.UnexpectedResult,
            }
        }
    }

    pub fn getMode(self: Self, pin: Pin) !Mode {
        const result = self.lib.gpio.getMode(@intFromEnum(pin));
        if (result >= 0) {
            return @enumFromInt(result);
        }

        const err = LibErrorCode.from_c_int(result);
        switch (err) {
            .PI_BAD_GPIO => unreachable, // PIN enum already checked
            else => return Error.UnexpectedResult,
        }
    }

    pub fn setPullUpDown(self: Self, pin: Pin, pud: PUD) !void {
        const result = self.lib.gpio.setPullUpDown(
            @intFromEnum(pin),
            @intFromEnum(pud),
        );
        if (result < 0) {
            const err = LibErrorCode.from_c_int(result);
            switch (err) {
                .PI_BAD_GPIO => unreachable, // PIN enum already checked
                .PI_BAD_PUD => unreachable, // PUD enum already checked
                else => return Error.UnexpectedResult,
            }
        }
    }

    pub fn read(self: Self, pin: Pin) !Level {
        const result = self.lib.gpio.read(@intFromEnum(pin));
        if (result < 0) {
            const err = LibErrorCode.from_c_int(result);
            switch (err) {
                .PI_BAD_GPIO => unreachable, // PIN enum already checked
                else => return Error.UnexpectedResult,
            }
        }
        return @enumFromInt(result);
    }

    pub fn write(self: Self, pin: Pin, level: Level) !void {
        const result = self.lib.gpio.write(
            @intFromEnum(pin),
            @intFromEnum(level),
        );
        if (result < 0) {
            const err = LibErrorCode.from_c_int(result);
            std.debug.print("Error writing pin {}: {}\n", .{ @intFromEnum(pin), err });
            switch (err) {
                .PI_BAD_GPIO => unreachable, // PIN enum already checked
                .PI_BAD_LEVEL => unreachable, // Level enum already checked
                else => return Error.UnexpectedResult,
            }
        }
    }

    pub const Mode = enum(u8) {
        Input = 0,
        Output = 1,
        Alt0 = 4,
        Alt1 = 5,
        Alt2 = 6,
        Alt3 = 7,
        Alt4 = 3,
        Alt5 = 2,
    };

    pub const PUD = enum(u8) {
        Off = 0,
        Down = 1,
        Up = 2,
    };

    pub const Level = enum(u8) {
        Low = 0,
        High = 1,
    };

    pub const Pin = enum(u8) {
        BCM0 = 0,
        BCM1 = 1,
        BCM2 = 2,
        BCM3 = 3,
        BCM4 = 4,
        BCM5 = 5,
        BCM6 = 6,
        BCM7 = 7,
        BCM8 = 8,
        BCM9 = 9,
        BCM10 = 10,
        BCM11 = 11,
        BCM12 = 12,
        BCM13 = 13,
        BCM14 = 14,
        BCM15 = 15,
        BCM16 = 16,
        BCM17 = 17,
        BCM18 = 18,
        BCM19 = 19,
        BCM20 = 20,
        BCM21 = 21,
        BCM22 = 22,
        BCM23 = 23,
        BCM24 = 24,
        BCM25 = 25,
        BCM26 = 26,
        BCM27 = 27,

        pub fn fromBCM(comptime bcm_pin_id: u8) Pin {
            return @enumFromInt(bcm_pin_id);
        }

        pub fn fromPhysical(comptime physical_pin_id: u8) Pin {
            const fields = @typeInfo(Pin).Enum.fields;
            for (fields) |field| {
                const instance: Pin = @field(Pin, field.name);
                if (instance.toPhysical() == physical_pin_id) {
                    return instance;
                }
            }

            @compileError("Invalid physical pin id");
        }

        pub fn toPhysical(self: Pin) u8 {
            return switch (self) {
                .BCM2 => 3,
                .BCM3 => 5,
                .BCM4 => 7,
                .BCM5 => 29,
                .BCM6 => 31,
                .BCM7 => 26,
                .BCM8 => 24,
                .BCM9 => 21,
                .BCM10 => 19,
                .BCM11 => 23,
                .BCM12 => 32,
                .BCM13 => 33,
                .BCM14 => 8,
                .BCM15 => 10,
                .BCM16 => 36,
                .BCM17 => 11,
                .BCM18 => 12,
                .BCM19 => 35,
                .BCM20 => 38,
                .BCM21 => 40,
                .BCM22 => 15,
                .BCM23 => 16,
                .BCM24 => 18,
                .BCM25 => 22,
                .BCM26 => 37,
                .BCM27 => 13,
                // BCM0 and 1 are special cases
                .BCM0 => 27,
                .BCM1 => 28,
            };
        }
    };

    pub const Error = error{
        FailedToInitialize,
        UnexpectedResult,
    };
};

const LibErrorCode = enum(c_int) {
    Success = 0,
    PI_INIT_FAILED = -1,
    PI_BAD_USER_GPIO = -2,
    PI_BAD_GPIO = -3,
    PI_BAD_MODE = -4,
    PI_BAD_LEVEL = -5,
    PI_BAD_PUD = -6,
    PI_BAD_PULSEWIDTH = -7,
    PI_BAD_DUTYCYCLE = -8,
    PI_BAD_TIMER = -9,
    PI_BAD_MS = -10,
    PI_BAD_TIMETYPE = -11,
    PI_BAD_SECONDS = -12,
    PI_BAD_MICROS = -13,
    PI_TIMER_FAILED = -14,
    PI_BAD_WDOG_TIMEOUT = -15,
    PI_NO_ALERT_FUNC = -16,
    PI_BAD_CLK_PERIPH = -17,
    PI_BAD_CLK_SOURCE = -18,
    PI_BAD_CLK_MICROS = -19,
    PI_BAD_BUF_MILLIS = -20,
    PI_BAD_DUTYRANGE = -21,
    PI_BAD_SIGNUM = -22,
    PI_BAD_PATHNAME = -23,
    PI_NO_HANDLE = -24,
    PI_BAD_HANDLE = -25,
    PI_BAD_IF_FLAGS = -26,
    PI_BAD_CHANNEL = -27,
    PI_BAD_SOCKET_PORT = -28,
    PI_BAD_FIFO_COMMAND = -29,
    PI_BAD_SECO_CHANNEL = -30,
    PI_NOT_INITIALISED = -31,
    PI_INITIALISED = -32,
    PI_BAD_WAVE_MODE = -33,
    PI_BAD_CFG_INTERNAL = -34,
    PI_BAD_WAVE_BAUD = -35,
    PI_TOO_MANY_PULSES = -36,
    PI_TOO_MANY_CHARS = -37,
    PI_NOT_SERIAL_GPIO = -38,
    PI_BAD_SERIAL_STRUC = -39,
    PI_BAD_SERIAL_BUF = -40,
    PI_NOT_PERMITTED = -41,
    PI_SOME_PERMITTED = -42,
    PI_BAD_WVSC_COMMND = -43,
    PI_BAD_WVSM_COMMND = -44,
    PI_BAD_WVSP_COMMND = -45,
    PI_BAD_PULSELEN = -46,
    PI_BAD_SCRIPT = -47,
    PI_BAD_SCRIPT_ID = -48,
    PI_BAD_SER_OFFSET = -49,
    PI_GPIO_IN_USE = -50,
    PI_BAD_SERIAL_COUNT = -51,
    PI_BAD_PARAM_NUM = -52,
    PI_DUP_TAG = -53,
    PI_TOO_MANY_TAGS = -54,
    PI_BAD_SCRIPT_CMD = -55,
    PI_BAD_VAR_NUM = -56,
    PI_NO_SCRIPT_ROOM = -57,
    PI_NO_MEMORY = -58,
    PI_SOCK_READ_FAILED = -59,
    PI_SOCK_WRIT_FAILED = -60,
    PI_TOO_MANY_PARAM = -61,
    PI_SCRIPT_NOT_READY = -62,
    PI_BAD_TAG = -63,
    PI_BAD_MICS_DELAY = -64,
    PI_BAD_MILS_DELAY = -65,
    PI_BAD_WAVE_ID = -66,
    PI_TOO_MANY_CBS = -67,
    PI_TOO_MANY_OOL = -68,
    PI_EMPTY_WAVEFORM = -69,
    PI_NO_WAVEFORM_ID = -70,
    PI_I2C_OPEN_FAILED = -71,
    PI_SER_OPEN_FAILED = -72,
    PI_SPI_OPEN_FAILED = -73,
    PI_BAD_I2C_BUS = -74,
    PI_BAD_I2C_ADDR = -75,
    PI_BAD_SPI_CHANNEL = -76,
    PI_BAD_FLAGS = -77,
    PI_BAD_SPI_SPEED = -78,
    PI_BAD_SER_DEVICE = -79,
    PI_BAD_SER_SPEED = -80,
    PI_BAD_PARAM = -81,
    PI_I2C_WRITE_FAILED = -82,
    PI_I2C_READ_FAILED = -83,
    PI_BAD_SPI_COUNT = -84,
    PI_SER_WRITE_FAILED = -85,
    PI_SER_READ_FAILED = -86,
    PI_SER_READ_NO_DATA = -87,
    PI_UNKNOWN_COMMAND = -88,
    PI_SPI_XFER_FAILED = -89,
    PI_BAD_POINTER = -90,
    PI_NO_AUX_SPI = -91,
    PI_NOT_PWM_GPIO = -92,
    PI_NOT_SERVO_GPIO = -93,
    PI_NOT_HCLK_GPIO = -94,
    PI_NOT_HPWM_GPIO = -95,
    PI_BAD_HPWM_FREQ = -96,
    PI_BAD_HPWM_DUTY = -97,
    PI_BAD_HCLK_FREQ = -98,
    PI_BAD_HCLK_PASS = -99,
    PI_HPWM_ILLEGAL = -100,
    PI_BAD_DATABITS = -101,
    PI_BAD_STOPBITS = -102,
    PI_MSG_TOOBIG = -103,
    PI_BAD_MALLOC_MODE = -104,
    PI_TOO_MANY_SEGS = -105,
    PI_BAD_I2C_SEG = -106,
    PI_BAD_SMBUS_CMD = -107,
    PI_NOT_I2C_GPIO = -108,
    PI_BAD_I2C_WLEN = -109,
    PI_BAD_I2C_RLEN = -110,
    PI_BAD_I2C_CMD = -111,
    PI_BAD_I2C_BAUD = -112,
    PI_CHAIN_LOOP_CNT = -113,
    PI_BAD_CHAIN_LOOP = -114,
    PI_CHAIN_COUNTER = -115,
    PI_BAD_CHAIN_CMD = -116,
    PI_BAD_CHAIN_DELAY = -117,
    PI_CHAIN_NESTING = -118,
    PI_CHAIN_TOO_BIG = -119,
    PI_DEPRECATED = -120,
    PI_BAD_SER_INVERT = -121,
    PI_BAD_EDGE = -122,
    PI_BAD_ISR_INIT = -123,
    PI_BAD_FOREVER = -124,
    PI_BAD_FILTER = -125,
    PI_BAD_PAD = -126,
    PI_BAD_STRENGTH = -127,
    PI_FIL_OPEN_FAILED = -128,
    PI_BAD_FILE_MODE = -129,
    PI_BAD_FILE_FLAG = -130,
    PI_BAD_FILE_READ = -131,
    PI_BAD_FILE_WRITE = -132,
    PI_FILE_NOT_ROPEN = -133,
    PI_FILE_NOT_WOPEN = -134,
    PI_BAD_FILE_SEEK = -135,
    PI_NO_FILE_MATCH = -136,
    PI_NO_FILE_ACCESS = -137,
    PI_FILE_IS_A_DIR = -138,
    PI_BAD_SHELL_STATUS = -139,
    PI_BAD_SCRIPT_NAME = -140,
    PI_BAD_SPI_BAUD = -141,
    PI_NOT_SPI_GPIO = -142,
    PI_BAD_EVENT_ID = -143,
    PI_CMD_INTERRUPTED = -144,
    PI_NOT_ON_BCM2711 = -145,
    PI_ONLY_ON_BCM2711 = -146,

    pub fn from_c_int(value: c_int) LibErrorCode {
        return @enumFromInt(value);
    }
};
