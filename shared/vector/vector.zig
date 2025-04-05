const std = @import("std");


pub const Vec2D = struct {
    array: [2]f64,

    const Self = @This();

    pub fn init(x: f64, y: f64) Self {
        return .{[_]f64{x, y}};
    }

    pub fn getX(self: Self) f64 {
        return self.array[0];
    }

    pub fn setX(self: *Self, x: f64) void {
        self.array[0] = x;
    }

    pub fn refX(self: *Self) *f64 {
        return &self.array[0];
    }

    pub fn getY(self: Self) f64 {
        return self.array[1];
    }

    pub fn setY(self: *Self, y: f64) void {
        self.array[1] = y;
    }

    pub fn refY(self: *Self) *f64 {
        return &self.array[1];
    }

    pub fn getDimension(self: Self, dimension: usize) f64 {
        return self.array[dimension];
    }

    pub fn distanceNoRoot(self: Self, vec: Vec2D) f64 {
        return std.math.powi(f64, self.getX() - vec.getX(), 2) 
                + std.math.powi(f64, self.getY() - vec.getY(), 2);
    }

    pub fn distance(self: Self, vec: Vec2D) f64 {
        return std.math.sqrt(self.distanceNoRoot(vec));
    }
};

pub const Vec3D = struct {
    array: [3]f64,

    const Self = @This();

    pub fn init(x: f64, y: f64, z: f64) Self {
        return .{[_]f64{x, y, z}};
    }

    pub fn getX(self: Self) f64 {
        return self.array[0];
    }

    pub fn setX(self: *Self, x: f64) void {
        self.array[0] = x;
    }

    pub fn refX(self: *Self) *f64 {
        return &self.array[0];
    }

    pub fn getY(self: Self) f64 {
        return self.array[1];
    }

    pub fn setY(self: *Self, y: f64) void {
        self.array[1] = y;
    }

    pub fn refY(self: *Self) *f64 {
        return &self.array[1];
    }

    pub fn getZ(self: Self) f64 {
        return self.array[2];
    }

    pub fn setZ(self: *Self, z: f64) void {
        self.array[2] = z;
    }

    pub fn refZ(self: *Self) *f64 {
        return &self.array[2];
    }

    pub fn getDimension(self: Self, dimension: usize) f64 {
        return self.array[dimension];
    }
    
    pub fn distanceNoRoot(self: Self, vec: Vec2D) f64 {
        return std.math.powi(f64, self.getX() - vec.getX(), 2) 
                + std.math.powi(f64, self.getY() - vec.getY(), 2) 
                + std.math.powi(f64, self.getZ() - vec.getZ(), 2);
    }

    pub fn distance(self: Self, vec: Vec2D) f64 {
        return std.math.sqrt(self.distanceNoRoot(vec));
    }
};
