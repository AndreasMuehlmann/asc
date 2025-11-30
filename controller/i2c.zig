const i2c = @cImport(@cInclude("i2c.h"));


pub const I2c = struct {
    const Self = @This();

    pub fn init() Self {
    }
};
