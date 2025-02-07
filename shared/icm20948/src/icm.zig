const std = @import("std");

const pigpio = @cImport(@cInclude("pigpio.h"));

pub const ADDR_L: c_uint = 0x69;
pub const ADDR_H: c_uint = 0x68;

const DEFAULT_WHO_AM_I = 0xEA;
const ADDR_WHO_AM_I = 0x00;

const ADDR_USER_CTRL = 0x03;

const ADDR_PWR_MGMT_1 = 0x06;

const ADDR_GYRO_OUT = 0x33;
const ADDR_ACCEL_OUT = 0x2D;

const ADDR_REG_BANK_SEL = 0x7F;

const ADDR_GYRO_SMPLRT_DIV = 0x00;
const ADDR_GYRO_CONFIG_1 = 0x01;

const ADDR_ACCEL_CONFIG = 0x14;
const ADDR_ACCEL_SMPLRT_DIV_1 = 0x10;
const ADDR_ACCEL_SMPLRT_DIV_2 = 0x11;

const ADDR_I2C_MST_CTRL = 0x01;

const ADDR_MAG_WIA = 0x01;
const ADDR_MAG_HXL = 0x11;
const ADDR_MAG_CNTL2 = 0x31;

const ADDR_EXT_SLV_SENS_DATA_00 = 0x3B;

const ADDR_I2C_SLV0_ADDR = 0x03;
const ADDR_I2C_SLV0_REG = 0x04;
const ADDR_I2C_SLV0_CTRL = 0x05;
const ADDR_I2C_SLV0_DO = 0x06;

const IcmError = error{
    OpenI2cBus,
    I2cRead,
    I2cWrite,
    IncorrectWhoAmI,
    MagnetometerOverflow,
};

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

        var self: Self = .{ .allocator = allocator, .handle = handle, .bank = 0 };
        try self.writeByte(ADDR_REG_BANK_SEL, 0);

        const whoAmI = try self.readByte(ADDR_WHO_AM_I);
        if (whoAmI != DEFAULT_WHO_AM_I) {
            return IcmError.IncorrectWhoAmI;
        }

        //try self.writeByte(ADDR_PWR_MGMT_1, 0b10000000);
        try self.writeByte(ADDR_PWR_MGMT_1, 0x01);
        //return IcmError.IncorrectWhoAmI;

        try self.setBank(2);

        try self.writeByte(ADDR_GYRO_SMPLRT_DIV, 10);
        try self.writeByte(ADDR_GYRO_CONFIG_1, 0b00010111);

        std.debug.print("ACCEL_CONFIG: {b}\n", .{try self.readByte(ADDR_ACCEL_CONFIG)});
        try self.writeByte(ADDR_ACCEL_CONFIG, 0b00010111);
        std.debug.print("ACCEL_CONFIG: {b}\n", .{try self.readByte(ADDR_ACCEL_CONFIG)});
        try self.writeByte(ADDR_ACCEL_SMPLRT_DIV_1, 0);
        try self.writeByte(ADDR_ACCEL_SMPLRT_DIV_2, 0x0A);

        try self.setBank(3);

        const byte = try self.readByte(ADDR_I2C_MST_CTRL);

        std.debug.print("MST_CTRL: {b}\n", .{byte});
        std.debug.print("MST_CTRL: {b}\n", .{(byte & 0b11110000) | 0b00010111});

        //try self.writeByte(ADDR_I2C_MST_CTRL, (byte & 0b11110000) | 0b00010111);
        try self.writeByte(ADDR_I2C_MST_CTRL, 0b00000111);
        std.debug.print("I2C_MST_CTRL: {b}\n", .{try self.readByte(ADDR_I2C_MST_CTRL)});

        try self.setBank(0);
        try self.writeByteEnable(ADDR_USER_CTRL, 0b00100000);

        try self.setReadBlockMag(ADDR_MAG_WIA, 1);

        try self.setBank(0);
        std.debug.print("USER_CTRL: {b}\n", .{try self.readByte(ADDR_USER_CTRL)});

        try self.setBank(3);
        std.debug.print("Bank: {b}\n", .{try self.readByte(ADDR_REG_BANK_SEL)});
        std.debug.print("I2C_MST_CTRL: {b}\n", .{try self.readByte(ADDR_I2C_MST_CTRL)});
        std.debug.print("I2C_SLV0_CTRL: {b}\n", .{try self.readByte(ADDR_I2C_SLV0_CTRL)});
        std.debug.print("I2C_SLV0_ADDR: {b}\n", .{try self.readByte(ADDR_I2C_SLV0_ADDR)});
        std.debug.print("I2C_SLV0_REG: {b}\n", .{try self.readByte(ADDR_I2C_SLV0_REG)});
        std.debug.print("I2C_SLV0_DO: {b}\n", .{try self.readByte(ADDR_I2C_SLV0_DO)});
        const maxTries: usize = 5;
        for (0..maxTries) |tries| {
            try self.setBank(0);
            const magDeviceId = try self.readByte(ADDR_EXT_SLV_SENS_DATA_00);
            if (magDeviceId != 9) {
                if (tries >= maxTries - 1) {
                    return error.IncorrectWhoAmI;
                }
                try self.writeByteEnable(ADDR_USER_CTRL, 0b10);
                std.time.sleep(100_000_000);
                continue;
            }
            break;
        }

        try self.writeByteMag(ADDR_MAG_CNTL2, 0b00001000);

        try self.setReadBlockMag(ADDR_MAG_HXL, 8);

        return self;
    }

    fn setBank(self: *Self, bank: u8) !void {
        if (self.bank != bank) {
            try self.writeByte(ADDR_REG_BANK_SEL, bank);
            self.bank = bank;
        }
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

    fn writeByteEnable(self: Self, register: c_uint, byte: u8) !void {
        const read = try self.readByte(register);
        try self.writeByte(register, read | byte);
    }

    fn writeByteDisable(self: Self, register: c_uint, byte: u8) !void {
        const read = try self.readByte(register);
        try self.writeByte(register, read & byte);
    }

    fn writeBlock(self: Self, register: c_uint, slice: []const u8) !void {
        const writeResult = pigpio.i2cWriteByteData(self.handle, register, @ptrCast(slice), @intCast(slice.len));
        if (writeResult < 0) {
            std.log.err("I2c write resulted in error {d}.", .{writeResult});
            return IcmError.I2cWrite;
        }
    }

    fn setReadBlockMag(self: *Self, register: u8, length: u8) !void {
        try self.setBank(3);
        try self.writeByteEnable(ADDR_I2C_SLV0_ADDR, 0x8C);
        try self.writeByte(ADDR_I2C_SLV0_REG, register);
        var byte = try self.readByte(ADDR_I2C_SLV0_CTRL);
        byte &= 0b11110000;
        byte |= 0b10000000 | length;
        try self.writeByte(ADDR_I2C_SLV0_CTRL, byte);
    }

    fn writeByteMag(self: *Self, register: u8, byte: u8) !void {
        try self.setBank(3);
        try self.writeByte(ADDR_I2C_SLV0_ADDR, 0x0C);
        try self.writeByte(ADDR_I2C_SLV0_REG, register);
        try self.writeByte(ADDR_I2C_SLV0_DO, byte);

        var ctrlByte = try self.readByte(ADDR_I2C_SLV0_CTRL);
        ctrlByte &= 0b11110000;
        ctrlByte |= 0b10000001;
        try self.writeByte(ADDR_I2C_SLV0_CTRL, ctrlByte);
    }

    pub fn readGyro(self: *Self) !@Vector(3, f32) {
        try self.setBank(0);

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

    pub fn readAccel(self: *Self) !@Vector(3, f32) {
        try self.setBank(0);

        var rawData: [6]u8 = undefined;
        try self.readBlock(ADDR_ACCEL_OUT, &rawData);

        const x: i16 = @bitCast(@as(u16, rawData[0]) << 8 | @as(u16, rawData[1]));
        const y: i16 = @bitCast(@as(u16, rawData[2]) << 8 | @as(u16, rawData[3]));
        const z: i16 = @bitCast(@as(u16, rawData[4]) << 8 | @as(u16, rawData[5]));

        const vector = @Vector(3, f32){
            @floatFromInt(x),
            @floatFromInt(y),
            @floatFromInt(z),
        };

        const sensitivityBasedOnAccelRange: f32 = 4;

        const scale: @Vector(3, f32) = @splat(9.81 / (sensitivityBasedOnAccelRange * 1_000));
        return vector * scale;
    }

    pub fn readMag(self: *Self) !@Vector(3, f32) {
        try self.setBank(0);

        var rawData: [8]u8 = undefined;
        try self.readBlock(ADDR_EXT_SLV_SENS_DATA_00, &rawData);

        if (rawData[7] & 0b00001000 > 0) {
            return IcmError.MagnetometerOverflow;
        }

        const x: i16 = @bitCast(@as(u16, rawData[0]) << 8 | @as(u16, rawData[1]));
        const y: i16 = @bitCast(@as(u16, rawData[2]) << 8 | @as(u16, rawData[3]));
        const z: i16 = @bitCast(@as(u16, rawData[4]) << 8 | @as(u16, rawData[5]));

        const vector = @Vector(3, f32){
            @floatFromInt(x),
            @floatFromInt(y),
            @floatFromInt(z),
        };

        return vector;
    }

    pub fn deinit(self: Self) void {
        _ = pigpio.i2cClose(self.handle);
    }
};
