pub const Point = struct {
    x: f64,
    y: f64,

    const Self = @This();

    pub fn getDimension(self: Self, dimension: usize) f64 {
        if (dimension == 0) {
            return self.x;
        } else if (dimension == 1) {
            return self.y;
        }
        unreachable;
    }
};
