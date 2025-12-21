const std = @import("std");

const utils = @cImport(@cInclude("utils.h"));
const utilsZig = @import("utils.zig");
const i2c = @cImport(@cInclude("i2c.h"));
const bmi = @cImport(@cInclude("bmi.h"));
const bmiBosch = @cImport(@cInclude("bmi270.h"));

const esp = @cImport({
    @cInclude("esp_log.h");
});


const c = @cImport({
    @cInclude("stdio.h");
});

const tag = "bmi270";


pub const Bmi = struct {
    const Self = @This();

    i2cDeviceHandle: i2c.i2c_master_dev_handle_t,
    prevMeasurementTime: i64,
    prevGyro: bmi.vec,
    prevAccel: bmi.vec,
    heading: f32,

    pub fn init(i2cBusHandle: *i2c.i2c_master_bus_handle_t) !Self {
        var i2cDeviceHandle: i2c.i2c_master_dev_handle_t = null;
        i2c.i2c_device_init(i2cBusHandle, &i2cDeviceHandle, bmiBosch.BMI2_I2C_PRIM_ADDR);

        const result: c_int = bmi.bmiInit(&i2cDeviceHandle);
        if (result < 0) {
            utils.espLog(esp.ESP_LOG_ERROR, tag, "Failed to initialize BMI270");
            return error.Bmi270InitFailed;
        }
        utils.espLog(esp.ESP_LOG_INFO, tag, "Initialized BMI270 successfully");
        return .{
            .i2cDeviceHandle = i2cDeviceHandle,
            .prevMeasurementTime = utilsZig.timestampMicros(),
            .prevGyro = .{.x = 0, .y = 0, .z = 0},
            .prevAccel = .{.x = 0, .y = 0, .z = 0},
            .heading = 0,
        };
    }

    pub fn update(self: *Self) !void {
        var gyro: bmi.vec = .{};
        var accel: bmi.vec = .{};
        const resultRead: c_int = bmi.bmiReadSensors(&gyro, &accel);
        if (resultRead == -1) {
            utils.espLog(esp.ESP_LOG_ERROR, tag, "Failed to read measurements from BMI270");
            return error.BmiReadFailed;
        } else if (resultRead == -2) {
            return;
        }            

        const currentTime = utilsZig.timestampMicros();
        const timeDiffMicro: f32 = @floatFromInt(currentTime - self.prevMeasurementTime);
        
        self.heading = @mod(self.heading + 0.5 * (self.prevGyro.z + gyro.z) * timeDiffMicro / 1_000_000, 360.0);
        self.prevMeasurementTime = currentTime;
        self.prevGyro = gyro;
        self.prevAccel = accel;
    }
};
