const std = @import("std");

const Point = @import("point.zig").Point;
const quickselect = @import("quickselect.zig");


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

const Node = struct {
    point: Point,
    left: ?*Node,
    right: ?*Node,
    splittingDimension: usize,

    const Self = @This();

    fn getDimension(self: Self) f64 {
        return self.point.getDimension(self.splittingDimension);
    }

    pub fn initSubTree(allocator: std.mem.Allocator, points: []Point, dimension: usize) !?*Self {
        if (points.len == 0) {
            return null;
        }
        const node: *Node = try allocator.create(Node);
        if (points.len == 1) {
            node.point = points[0];
            node.left = null;
            node.right = null;
            node.splittingDimension = dimension;
            return node;
        }

        const pivotIndex: usize = quickselect.quickselect(points, points.len / 2, dimension);
        const newDimension = (dimension + 1) % 2;
        node.point = points[pivotIndex];
        node.left = try Node.initSubTree(allocator, points[0..pivotIndex], newDimension);
        node.right = try Node.initSubTree(allocator, points[pivotIndex + 1 ..], newDimension);
        node.splittingDimension = dimension;
        return node;
    }

    pub fn insert(self: *Self, node: *Node) void {
        node.splittingDimension = (node.splittingDimension + 1) % 2;
        if (node.getDimension() < self.getDimension()) {
            if (self.left) |l| {
                l.insert(node);
            } else {
                self.left = node;
            }
        } else {
            if (self.right) |r| {
                r.insert(node);
            } else {
                self.right = node;
            }
        }
    }

    pub fn nearestNeighbor(self: Self, point: Point) Point {
        const treeValue: f64 = self.getDimension();
        const value: f64 = point.getDimension(self.splittingDimension);

        var nn: Point = self.point;
        var otherSubtree: ?*Node = null;

        if (value < treeValue) {
            otherSubtree = self.right;
            if (self.left) |l| {
                nn = l.nearestNeighbor(point);
            }        
        } else {
            otherSubtree = self.left;
            if (self.right) |r| {
                nn = r.nearestNeighbor(point);
            }
        }

        if (point.calcSquaredDistance(self.point) < point.calcSquaredDistance(nn)) {
            nn = self.point;
        }

        if (otherSubtree) |node| {

            if ((treeValue - value) * (treeValue - value) < point.calcSquaredDistance(nn)) {
                const nnOtherSubtree: Point = node.nearestNeighbor(point);

                if (point.calcSquaredDistance(nnOtherSubtree) < point.calcSquaredDistance(nn)) {
                    nn = nnOtherSubtree;
                }
            }
        }

        return nn;
    }

    pub fn print(self: Self, id: usize) !usize {
        var buffer: [100]u8 = undefined;
        const stdout = std.io.getStdOut().writer();
        try stdout.writeAll(try std.fmt.bufPrint(&buffer, "    {d} [label = \"({d:.1}, {d:.1}) {d}\"];\n", .{id, self.point.x, self.point.y, self.splittingDimension}));
        var subTreeSize: usize = 1;
        if (self.left) |l| {
            try stdout.writeAll(try std.fmt.bufPrint(&buffer, "    {d} -> {d};\n", .{id, id + 1}));
            subTreeSize += try l.print(id + 1);
        }
        if (self.right) |r| {
            try stdout.writeAll(try std.fmt.bufPrint(&buffer, "    {d} -> {d};\n", .{id, id + subTreeSize}));
            subTreeSize += try r.print(id + subTreeSize);
        }
        return subTreeSize;
    }

    pub fn deinitSubTree(self: *Self, allocator: std.mem.Allocator) void {
        if (self.left) |l| {
            l.deinitSubTree(allocator);
        }
        if (self.right) |r| {
            r.deinitSubTree(allocator);
        }
        allocator.destroy(self);
    }
};

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
        .{ .x = 0, .y = 0 },
        .{ .x = 0, .y = 0 },
        .{ .x = -1, .y = 0 },
        .{ .x = 4, .y = 0 },
        .{ .x = 20, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 5, .y = 0 },
        .{ .x = 9, .y = 0 },
        .{ .x = 7, .y = 0 },
    };

    var kdTree: KdTree = try KdTree.init(testing.allocator, &points);
    defer kdTree.deinit();

    try kdTree.insert(.{ .x = 5, .y = 5 });
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
