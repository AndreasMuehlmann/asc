const std = @import("std");
const os = std.os;
const net = std.net;

const pigpio = @cImport(@cInclude("pigpio.h"));
const bnoApi = @cImport(@cInclude("bno055.h"));

const PigpioError = error{
    InitializationError,
    I2cInitializationError,
    I2cClosingError,
    DeviceCommunicationError,
};

pub fn BNO055_I2C_bus_read(dev_addr: u8, reg_addr: u8, data: [*c]u8, length: u8) callconv(.C) i8 {
    const openResult = pigpio.i2cOpen(1, dev_addr, 0);
    if (openResult < 0) {
        std.log.err("Failure while creating i2c handle in bus read.\n", .{});
        return 1;
    }
    const handle: c_uint = @intCast(openResult);
    const result = pigpio.i2cReadI2CBlockData(handle, reg_addr, data, length);
    if (result <= 0) {
        std.log.err("Result in read indicates an error: %d (PI_BAD_HANDLE -25, PI_BAD_PARAM -81, PI_I2C_READ_FAILED -83).\n", .{});
        return 1;
    }
    _ = pigpio.i2cClose(handle);
    return 0;
}

pub fn BNO055_I2C_bus_write(dev_addr: u8, reg_addr: u8, data: [*c]u8, length: u8) callconv(.C) i8 {
    const openResult = pigpio.i2cOpen(1, dev_addr, 0);
    if (openResult < 0) {
        std.log.err("Failure while creating i2c handle in bus write.\n", .{});
        return 1;
    }
    const handle: c_uint = @intCast(openResult);
    const result = pigpio.i2cWriteI2CBlockData(handle, reg_addr, data, length);
    if (result < 0) {
        std.log.err("Result in write indicates an error: %d (PI_BAD_HANDLE -25, PI_BAD_PARAM -81, PI_I2C_READ_FAILED -83).\n", .{});
        return 1;
    }
    _ = pigpio.i2cClose(handle);
    return 0;
}

pub fn delay(ms: c_uint) callconv(.C) void {
    _ = pigpio.gpioDelay(ms * 1000);
}

pub fn signalForcingExitHandler(sig: c_int) callconv(.C) void {
    _ = sig;

    std.log.warn("Received signal to exit.\n", .{});
    pigpio.gpioTerminate();
    std.process.exit(1);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    if (pigpio.gpioInitialise() < 0) {
        std.log.err("Failure in gpioInitialise.\n", .{});
        return PigpioError.InitializationError;
    }
    defer pigpio.gpioTerminate();

    const act = os.linux.Sigaction{
        .handler = .{ .handler = signalForcingExitHandler },
        .mask = os.linux.empty_sigset,
        .flags = 0,
    };

    if (os.linux.sigaction(os.linux.SIG.INT, &act, null) != 0) {
        return error.SignalHandlerError;
    }

    var bno: bnoApi.bno055_t = bnoApi.bno055_t{
        .bus_read = BNO055_I2C_bus_read,
        .bus_write = BNO055_I2C_bus_write,
        .delay_msec = delay,
        .dev_addr = bnoApi.BNO055_I2C_ADDR1,
    };
    const ptrBno: [*c]bnoApi.bno055_t = @ptrCast(&bno);

    if (bnoApi.bno055_init(ptrBno) != 0) {
        std.log.err("Failure in bno055_init.\n", .{});
        return PigpioError.DeviceCommunicationError;
    }

    if (bnoApi.bno055_set_operation_mode(bnoApi.BNO055_OPERATION_MODE_NDOF) != 0) {
        std.log.err("Failure in bno055_set_operation_mode.\n", .{});
        return PigpioError.DeviceCommunicationError;
    }

    var euler = bnoApi.bno055_euler_float_t{
        .h = 0,
        .r = 0,
        .p = 0,
    };

    //   var accel_calib_status: u8 = 0;
    //   var gyro_calib_status: u8 = 0;
    //   var mag_calib_status: u8 = 0;
    //   var sys_calib_status: u8 = 0;

    const ptrEuler: [*c]bnoApi.bno055_euler_float_t = @ptrCast(&euler);

    const address = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, 8080);
    var server = try address.listen(.{});
    defer server.deinit();

    const start = std.time.milliTimestamp();
    while (true) {
        const connection = try server.accept();
        while (true) {
            if (bnoApi.bno055_convert_float_euler_hpr_deg(ptrEuler) != 0) {
                std.log.warn("Failed to read euler angles.\n", .{});
                pigpio.gpioTerminate();
                return PigpioError.DeviceCommunicationError;
            }

            const buffer = try std.fmt.allocPrint(allocator, "{d},{d:.2},{d:.2},{d:.2}\n", .{ start - std.time.milliTimestamp(), ptrEuler.*.h, ptrEuler.*.r, ptrEuler.*.p });
            try connection.stream.writeAll(buffer);
            allocator.free(buffer);
        }
        std.time.sleep(200_000_000);
    }

    //   for (0..100) |_| {
    //       std.debug.print("Euler angles: heading: {d:.2}, roll: {d:.2}, pitch: {d:.2}\n", .{ ptrEuler.*.h, ptrEuler.*.r, ptrEuler.*.p });
    //
    //       _ = bnoApi.bno055_get_gyro_calib_stat(&gyro_calib_status);
    //       _ = bnoApi.bno055_get_accel_calib_stat(&accel_calib_status);
    //       _ = bnoApi.bno055_get_mag_calib_stat(&mag_calib_status);
    //       _ = bnoApi.bno055_get_sys_calib_stat(&sys_calib_status);
    //
    //       std.debug.print("Calibration status: gyro {d}, accel {d}, mag {d}, sys {d}\n", .{ gyro_calib_status, accel_calib_status, mag_calib_status, sys_calib_status });
    //
    //       std.time.sleep(100_000_000);
    //   }
}
