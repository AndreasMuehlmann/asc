const std = @import("std");

const Point = @import("point.zig").Point;
const Node = @import("node.zig").Node;


pub fn main() !void {
    const maxLength = 1000;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var points: [maxLength]Point = undefined;
    for (0..100) |_| {
        const length = std.crypto.random.uintAtMost(usize, maxLength);
        if (length == 0) {
            continue;
        }
        for (0..length) |i| {
            points[i] = .{ .x = std.crypto.random.float(f64) * 100.0, .y = std.crypto.random.float(f64) * 100.0};
        }

        var kdTree: KdTree = try KdTree.init(gpa.allocator(), points[0..length]);
        defer kdTree.deinit();

        const point = .{ .x = std.crypto.random.float(f64) * 100.0, .y = std.crypto.random.float(f64) * 100.0};
        const nn: Point = kdTree.nearestNeighbor(point).?;
        const nnSlice: Point = nearestNeighborSlice(points[0..length], point).?;
        if (nnSlice.x != nn.x or nnSlice.y != nn.y) {
            try kdTree.print();
            std.log.err("point: {d:.1}, {d:.1}, nnSlice: {d:.1}, {d:.1}; nn {d:.1}, {d:.1}", .{point.x, point.y, nnSlice.x, nnSlice.y, nn.x, nn.y});
            return;
        }
    }
}


pub const KdTree = struct {
    root: ?*Node,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, points: []Point) !Self {
        return .{
            .allocator = allocator,
            .root = try Node.initSubTree(allocator, points, 0),
        };
    }

    pub fn insert(self: *Self, point: Point) !void {
        const node: *Node = try self.allocator.create(Node);
        node.point = point;
        node.left = null;
        node.right = null;
        node.splittingDimension = 0;

        if (self.root) |root| {
            root.insert(node);
        } else {
            self.root = node;
        }
    }

    pub fn nearestNeighbor(self: Self, point: Point) ?Point {
        if (self.root) |root| {
            return root.nearestNeighbor(point);
        }
        return null;
    }

    pub fn print(self: Self) !void {
        const stdout = std.io.getStdOut().writer();
        try stdout.writeAll("digraph 1 {\n");
        if (self.root) |root| {
            _ = try root.print(0);
        }
        try stdout.writeAll("}");
    }

    pub fn deinit(self: Self) void {
        if (self.root) |r|
            r.deinitSubTree(self.allocator);
    }
};

const testing = std.testing;

test "initAndInsert" {
    var points = [_]Point{
        .{ .x = -1, .y = 1 },
        .{ .x = 1, .y = 3 },
        .{ .x = 4, .y = 5 },
        .{ .x = 5, .y = 7 },
        .{ .x = 7, .y = 9 },
        .{ .x = 9, .y = 13 },
        .{ .x = 20, .y = 10 },
    };

    var kdTree: KdTree = try KdTree.init(testing.allocator, &points);
    defer kdTree.deinit();

    try kdTree.insert(.{ .x = 5, .y = 5 });

    try testing.expectEqual(5, kdTree.root.?.point.x);
    const rootl = kdTree.root.?.left.?;
    try testing.expectEqual(3, rootl.point.y);
    const rootr = kdTree.root.?.right.?;
    try testing.expectEqual(10, rootr.point.y);

    const rootll = rootl.left.?;
    try testing.expectEqual(-1, rootll.point.x);
    const rootlr = rootl.right.?;
    try testing.expectEqual(4, rootlr .point.x);
    const rootrl = rootr.left.?;
    try testing.expectEqual(7, rootrl.point.x);
    const rootrr = rootr.right.?;
    try testing.expectEqual(9, rootrr.point.x);

    const rootrll = rootrl.left.?;
    try testing.expectEqual(5, rootrll.point.y);
}

fn nearestNeighborSlice(points: []Point, point: Point) ?Point {
    if (points.len == 0) {
        return null;
    }
    var nn = points[0];
    for (points[1..]) |p| {
        if (point.calcSquaredDistance(p) < point.calcSquaredDistance(nn)) {
            nn = p;
        }
    }
    return nn;
}

test "nearestNeighbor" {
    var points = [_]Point{
        .{ .x = 1, .y = 0 },
        .{ .x = 4, .y = 4 },
        .{ .x = 2, .y = 3 },
        .{ .x = 1, .y = 1 },
        .{ .x = 5, .y = 0 },
        .{ .x = 9, .y = 9 },
        .{ .x = 7, .y = 2 },
    };

    var kdTree: KdTree = try KdTree.init(testing.allocator, &points);
    defer kdTree.deinit();

    const nn: Point = kdTree.nearestNeighbor(.{ .x = 5, .y = 5 }).?;
    try testing.expectEqual(4, nn.x);
    try testing.expectEqual(4, nn.y);
}

test "nearestNeighborAgainstSliceNearestNeighbor" {
    const maxLength = 1000;
    var points: [maxLength]Point = undefined;
    for (0..100) |_| {
        const length = std.crypto.random.uintAtMost(usize, maxLength);
        if (length == 0) {
            continue;
        }
        for (0..length) |i| {
            points[i] = .{ .x = std.crypto.random.float(f64) * 100.0, .y = std.crypto.random.float(f64) * 100.0};
        }

        var kdTree: KdTree = try KdTree.init(testing.allocator, points[0..length]);
        defer kdTree.deinit();

        const point = .{ .x = std.crypto.random.float(f64) * 100.0, .y = std.crypto.random.float(f64) * 100.0};
        const nn: Point = kdTree.nearestNeighbor(point).?;
        const nnSlice: Point = nearestNeighborSlice(points[0..length], point).?;
        try testing.expectEqual(nnSlice.x, nn.x);
        try testing.expectEqual(nnSlice.y, nn.y);
    }
}
