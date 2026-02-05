const std = @import("std");
const kdTreeMod = @import("kdTree");

pub fn Icp(comptime pointT: type) type {
    if (!@hasDecl(pointT, "init")) {
        @compileError("init(f64, f64) pointT has to be declared on a point type.");
    }
    if (@TypeOf(@field(pointT, "init")) != fn (f64, f64) pointT) {
        @compileError("init(f64, f64) pointT has to be declared on a point type and have the correct signature.");
    }
    if (!@hasDecl(pointT, "getX")) {
        @compileError("getX(pointT) f64 has to be declared on a point type.");
    }
    if (@TypeOf(@field(pointT, "getX")) != fn (pointT) f64) {
        @compileError("getX(pointT) f64 has to be declared on a point type and have the correct signature.");
    }
    if (!@hasDecl(pointT, "getY")) {
        @compileError("getY(pointT) f64 has to be declared on a point type.");
    }
    if (@TypeOf(@field(pointT, "getY")) != fn (pointT) f64) {
        @compileError("getY(pointT) f64 has to be declared on a point type and have the correct signature.");
    }
    const KdTree = kdTreeMod.KdTree(pointT, 2);
    return struct {
        source: []const pointT,
        destination: *const KdTree,
        iterations: usize,

        const Self = @This();

        pub fn init(source: []const pointT, destination: *const KdTree, iterations: usize) Self {
            return .{
                .source = source,
                .destination = destination,
                .iterations = iterations,
            };
        }

        pub fn icp(self: Self) f64 {
            var totalOffset: f64 = 0;
            for (0..self.iterations) |_| {
                var offsetSum: f64 = 0;
                for (self.source) |p| {
                    const point = pointT.init(p.getX() + totalOffset, p.getY());
                    const nn: pointT = self.destination.nearestNeighbor(point).?;
                    offsetSum += nn.getX() - point.getX();
                }
                const floatLen: f64 = @floatFromInt(self.source.len);
                totalOffset += offsetSum / floatLen;
            }
            return totalOffset;
        }
    };
}
