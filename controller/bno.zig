const std = @import("std");

const pigpio = @cImport(@cInclude("pigpio.h"));
const bnoApi = @cImport(@cInclude("bno055.h"));

const BnoError = error{ BnoOpenBusError, BnoCloseBusError, BnoInitialization, BnoSetMode, BnoGetEuler, BnoGetAcceleration };

var handle: c_uint = undefined;
var allocator: std.mem.Allocator = undefined;
var bno = bnoApi.bno055_t{
    .bus_read = bnoUartRead,
    .bus_write = bnoUartWrite,
    .delay_msec = delay,
    .dev_addr = bnoApi.BNO055_I2C_ADDR1,
};

fn delay(milliSeconds: u32) callconv(.C) void {
    _ = pigpio.gpioDelay(milliSeconds * 1000);
}

fn bnoUartRead(deviceAddress: u8, registerAddress: u8, data: [*c]u8, length: u8) callconv(.C) i8 {
    var message = [_]u8{ 0xAA, 0x01, registerAddress, length };
    const writeResult: c_int = pigpio.serWrite(handle, @ptrCast(&message), message.len);
    if (writeResult < 0) {
        std.log.err("Pigpio error code {d} in read while writing request.\n", .{writeResult});
        return 1;
    }

    delay(10);

    const responseHeaderResult: c_int = pigpio.serReadByte(handle);
    if (responseHeaderResult <= 0) {
        std.log.err("Pigpio error code {d} in read while reading result of request.\n", .{responseHeaderResult});
        return 1;
    }
    if (responseHeaderResult == 0xEE) {
        const statusByteResult: c_int = pigpio.serReadByte(handle);

        if (statusByteResult <= 0) {
            std.log.err("Pigpio error code {d} in read while reading result of request.\n", .{statusByteResult});
            return 1;
        }
        switch (statusByteResult) {
            0x01 => {
                std.log.err("Response after write attempt to bno055: WRITE_SUCCESS but no data responded in read.\n", .{});
                return 1;
            },
            0x03 => {
                std.log.err("Response after write attempt to bno055: WRITE_FAIL.\n", .{});
                return 1;
            },
            0x04 => {
                std.log.err("Response after write attempt to bno055: REGMAP_INVALID_ADDRESS.\n", .{});
                return 1;
            },
            0x06 => {
                std.log.err("Response after write attempt to bno055: WRONG_START_BYTE.\n", .{});
                return 1;
            },
            0x07 => {
                //std.log.info("Response after write attempt to bno055: BUS_OVER_RUN_ERROR.\n", .{});
                delay(10);
                return bnoUartRead(deviceAddress, registerAddress, data, length);
            },
            0x08 => {
                std.log.err("Response after write attempt to bno055: MAX_LENGTH_ERROR.\n", .{});
                return 1;
            },
            0x09 => {
                std.log.err("Response after write attempt to bno055: MIN_LENGTH_ERROR.\n", .{});
                return 1;
            },
            0x0A => {
                std.log.err("Response after write attempt to bno055: RECEIVE_CHARACTER_TIMEOUT.\n", .{});
                return 1;
            },
            else => {
                std.log.err("Unkown status code responded after write attempt to bno055: {d}.\n", .{statusByteResult});
                return 1;
            },
        }
    }
    if (responseHeaderResult != 0xBB) {
        std.log.err("Unkown response from bno055 after write attempt: {d}.\n", .{responseHeaderResult});
        return 1;
    }

    const responseSlice = allocator.alloc(u8, length + 1) catch {
        std.log.err("Allocation error while trying to read from uart bus.\n", .{});
        return 1;
    };
    const response: [*c]u8 = @ptrCast(responseSlice);
    const responseResult: c_int = pigpio.serRead(handle, response, length + 1);
    if (responseResult <= 0) {
        std.log.err("Pigpio error code {d} in read while reading result of request.\n", .{responseResult});
        allocator.free(responseSlice);
        return 1;
    }

    for (0..length) |index| {
        data[index] = response[index + 1];
    }

    allocator.free(responseSlice);
    return 0;
}

fn bnoUartWrite(deviceAddress: u8, registerAddress: u8, data: [*c]u8, length: u8) callconv(.C) i8 {
    const message = allocator.alloc(u8, length + 4) catch {
        std.log.err("Allocation error while trying to write to uart bus.\n", .{});
        return 1;
    };
    defer allocator.free(message);

    message[0] = 0xAA;
    message[1] = 0x00;
    message[2] = registerAddress;
    message[3] = length;

    for (0..length) |index| {
        message[index + 4] = data[index];
    }

    const writeResult: c_int = pigpio.serWrite(handle, message.ptr, length + 4);
    if (writeResult < 0) {
        std.log.err("Pigpio error code {d} in write while writing to bus.\n", .{writeResult});
        return 1;
    }

    delay(10);

    const response = allocator.alloc(u8, 2) catch {
        std.log.err("Allocation error while trying to write to uart bus.\n", .{});
        return 1;
    };
    defer allocator.free(response);
    const readResult: c_int = pigpio.serRead(handle, response.ptr, 2);
    if (readResult <= 0) {
        std.log.err("Pigpio error code {d} in reading write result.\n", .{readResult});
        return 1;
    }

    if (response[0] != 0xEE) {
        std.log.err("Response after write attempt: Expected 0xEE in write reponse as first byte got: {d}.\n", .{response[0]});
        return 1;
    }

    switch (response[1]) {
        0x01 => return 0,
        0x03 => {
            std.log.err("Response after write attempt: WRITE_FAIL.\n", .{});
            return 1;
        },
        0x04 => {
            std.log.err("Response after write attempt: REGMAP_INVALID_ADDRESS.\n", .{});
            return 1;
        },
        0x05 => {
            std.log.err("Response after write attempt: REGMAP_WRITE_DISABLED.\n", .{});
            return 1;
        },
        0x06 => {
            std.log.err("Response after write attempt: WRONG_START_BYTE.\n", .{});
            return 1;
        },
        0x07 => {
            //std.log.info("Response after write attempt: BUS_OVER_RUN_ERROR.\n", .{});
            delay(10);
            return bnoUartWrite(deviceAddress, registerAddress, data, length);
        },
        0x08 => {
            std.log.err("Response after write attempt: MAX_LENGTH_ERROR.\n", .{});
            return 1;
        },
        0x09 => {
            std.log.err("Response after write attempt: MIN_LENGTH_ERROR.\n", .{});
            return 1;
        },
        0x0A => {
            std.log.err("Response after write attempt: RECEIVE_CHARACTER_TIMEOUT.\n", .{});
            return 1;
        },
        else => {
            std.log.err("Unkown response code after write: {d}.\n", .{response[1]});
            return 1;
        },
    }

    return 0;
}

pub const Euler = struct {
    heading: f32,
    roll: f32,
    pitch: f32,

    pub fn fromCType(eulerCType: bnoApi.bno055_euler_float_t) Euler {
        return .{ .heading = eulerCType.h, .roll = eulerCType.r, .pitch = eulerCType.p };
    }
};

pub const Acceleration = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn fromCType(accelerationCType: bnoApi.bno055_linear_accel_float_t) Acceleration {
        return .{ .x = accelerationCType.x, .y = accelerationCType.y, .z = accelerationCType.z };
    }
};

pub const Bno = struct {
    const Self = @This();

    pub fn init(allocatorArg: std.mem.Allocator) !Self {
        allocator = allocatorArg;

        const device: [*:0]const u8 = "/dev/ttyS0";
        const openResult: c_int = pigpio.serOpen(@ptrCast(@constCast(device)), 115200, 0);
        if (openResult < 0) {
            std.log.err("Pigpio error code {d} in creating uart bus.\n", .{openResult});
            return BnoError.BnoOpenBusError;
        }
        errdefer _ = pigpio.serClose(handle);
        handle = @intCast(openResult);
        delay(50);

        const bnoPtr: [*c]bnoApi.bno055_t = @ptrCast(&bno);
        if (bnoApi.bno055_init(bnoPtr) != 0) {
            return BnoError.BnoInitialization;
        }

        if (bnoApi.bno055_set_operation_mode(bnoApi.BNO055_OPERATION_MODE_NDOF) != 0) {
            return BnoError.BnoSetMode;
        }

        return .{};
    }

    pub fn getEuler(_: Self) !Euler {
        var euler: bnoApi.bno055_euler_float_t = .{ .h = 0, .r = 0, .p = 0 };
        const eulerPtr: [*c]bnoApi.bno055_euler_float_t = @ptrCast(@constCast(&euler));
        if (bnoApi.bno055_convert_float_euler_hpr_deg(eulerPtr) != 0) {
            return BnoError.BnoGetEuler;
        }
        return Euler.fromCType(euler);
    }

    pub fn getAcceleration(_: Self) !Acceleration {
        var acceleration: bnoApi.bno055_linear_accel_float_t = .{ .x = 0, .y = 0, .z = 0 };
        const accelerationPtr: [*c]bnoApi.bno055_linear_accel_float_t = @ptrCast(@constCast(&acceleration));
        if (bnoApi.bno055_convert_float_linear_accel_xyz_msq(accelerationPtr) != 0) {
            return BnoError.BnoGetAcceleration;
        }

        return Acceleration.fromCType(acceleration);
    }

    pub fn deinit(_: Self) !void {
        const closingResult: c_int = pigpio.serClose(handle);
        if (closingResult < 0) {
            std.log.err("Pigpio error code {d} in closing uart bus.\n", .{closingResult});
            return BnoError.BnoCloseBusError;
        }
    }
};
