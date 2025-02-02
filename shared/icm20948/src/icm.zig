const std = @import("std");

const pigpio = @cImport(@cInclude("pigpio.h"));

pub const ADDR_L: c_uint = 0x69;
pub const ADDR_H: c_uint = 0x68;

const ADDR_REG_BANK_SEL = 0x7F;

const DEFAULT_WHO_AM_I = 0xEA;
const ADDR_WHO_AM_I = 0x00;

const ADDR_GYRO_OUT = 0x33;

const ADDR_GYRO_SMPLRT_DIV = 0x00;
const ADDR_GYRO_CONFIG_1 = 0x01;

const IcmError = error{ OpenI2cBus, I2cRead, I2cWrite, IncorrectWhoAmI };

pub const Icm = struct {
    allocator: std.mem.Allocator,
    handle: c_uint,
    bank: u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, addr: c_uint) !Self {
        const openResult: c_int = pigpio.i2cOpen(1, addr, 0);
        if (openResult < 0) {
            std.log.err("i2c bus couldn't be opened, pigpio error code {d}", .{openResult});
            return IcmError.OpenI2cBus;
        }
        const handle: c_uint = @intCast(openResult);

        const self: Self = .{ .allocator = allocator, .handle = handle, .bank = 0 };

        try self.writeByte(ADDR_REG_BANK_SEL, 0);
        const whoAmI = try self.readByte(ADDR_WHO_AM_I);
        if (whoAmI != DEFAULT_WHO_AM_I) {
            return IcmError.IncorrectWhoAmI;
        }

        try self.writeByte(ADDR_REG_BANK_SEL, 2);

        try self.writeByte(ADDR_GYRO_SMPLRT_DIV, 10);
        try self.writeByte(ADDR_GYRO_CONFIG_1, 0b00010111);

        return self;
    }

    fn readByte(self: Self, register: c_uint) !u8 {
        const readResult = pigpio.i2cReadByteData(self.handle, register);
        if (readResult < 0) {
            std.log.err("I2c read resulted in error {d}.", .{readResult});
            return IcmError.I2cRead;
        }
        return @intCast(readResult);
    }

    fn readBlock(self: Self, register: c_uint, slice: []u8) !void {
        const readResult = pigpio.i2cReadI2CBlockData(self.handle, register, @ptrCast(slice), @intCast(slice.len));
        if (readResult < 0) {
            std.log.err("I2c read resulted in error {d}.", .{readResult});
            return IcmError.I2cRead;
        }
    }

    fn writeByte(self: Self, register: c_uint, byte: u8) !void {
        const writeResult = pigpio.i2cWriteByteData(self.handle, register, @intCast(byte));
        if (writeResult < 0) {
            std.log.err("I2c write resulted in error {d}.", .{writeResult});
            return IcmError.I2cWrite;
        }
    }

    fn writeBlock(self: Self, register: c_uint, slice: []const u8) !void {
        const writeResult = pigpio.i2cWriteByteData(self.handle, register, @ptrCast(slice), @intCast(slice.len));
        if (writeResult < 0) {
            std.log.err("I2c write resulted in error {d}.", .{writeResult});
            return IcmError.I2cWrite;
        }
    }

    pub fn readGyro(self: Self) !@Vector(3, f32) {
        if (self.bank != 0) {
            try self.writeByte(ADDR_REG_BANK_SEL, 0);
        }

        var rawData: [6]u8 = undefined;
        try self.readBlock(ADDR_GYRO_OUT, &rawData);

        const x: i16 = @bitCast(@as(u16, rawData[0]) << 8 | @as(u16, rawData[1]));
        const y: i16 = @bitCast(@as(u16, rawData[2]) << 8 | @as(u16, rawData[3]));
        const z: i16 = @bitCast(@as(u16, rawData[4]) << 8 | @as(u16, rawData[5]));

        const vector = @Vector(3, f32){
            @floatFromInt(x),
            @floatFromInt(y),
            @floatFromInt(z),
        };

        const sensitivityBasedOnDps = 16.4;

        const scale: @Vector(3, f32) = @splat(std.math.pi / (sensitivityBasedOnDps * 180.0));
        return vector * scale;
    }

    pub fn deinit(self: Self) void {
        _ = pigpio.i2cClose(self.handle);
    }
};
