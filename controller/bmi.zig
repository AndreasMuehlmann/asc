const std = @import("std");
const bmiApi = @cImport(@cInclude("bmi270.h"));
const i2c = @cImport(@cInclude("i2c.h"));

pub const Bmi = struct {
    const Self = @This();

    var busHandle: i2c.i2c_master_dev_handle_t = null;

    pub fn init(bHandle: i2c.i2c_master_dev_handle_t) Self {
        busHandle = bHandle;
        return .{};
    }
};
