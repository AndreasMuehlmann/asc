const std = @import("std");

const Vec2D = @import("vector").Vec2D;
const KdTree = @import("kdTree").KdTree(Vec2D, 2);


pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const icp = try Icp.init(gpa.allocator());
    defer icp.deinit();
}


const Icp = struct {
    allocator: std.mem.Allocator,
    destination: std.ArrayList(Vec2D),
    source: std.ArrayList(Vec2D),
    kdTree: KdTree,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        return .{
            .allocator = allocator,
            .destination = std.ArrayList(Vec2D).init(allocator),
            .source = std.ArrayList(Vec2D).init(allocator),
            .kdTree = try KdTree.init(allocator, &.{}),
        };
    }

    fn nearestNeighborSlice(points: []Vec2D, point: Vec2D) ?Vec2D {
        if (points.len == 0) {
            return null;
        }
        var nn = points[0];
        for (points[1..]) |p| {
            if (point.distanceNoRoot(p) < point.distanceNoRoot(nn)) {
                nn = p;
            }
        }
        return nn;
    }

    pub fn deinit(self: Self) void {
        self.destination.deinit();
        self.source.deinit();
        self.kdTree.deinit();
    }
};
