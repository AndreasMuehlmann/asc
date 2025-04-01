const std = @import("std");

const Point = @import("point.zig").Point;
const quickselect = @import("quickselect.zig");

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
        if (node.getDimension() < self.getDimension()) {
            if (self.left) |l|{
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

        var nn: Point = undefined;
        var otherSubtree: ?*Node = null;

        if (value < treeValue) {
            if (self.left) |l| {
                nn = l.nearestNeighbor(point);
                otherSubtree = self.right;
            } else {
                return self.point;
            }
        } else {
            if (self.right) |r| {
                nn = r.nearestNeighbor(point);
                otherSubtree = self.left;
            } else {
                return self.point;
            }
        }
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

    pub fn deinit(self: Self) void {
        if (self.root) |r|
            r.deinitSubTree(self.allocator);
    }
};

const testing = std.testing;

test "init" {
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

    try kdTree.insert(.{.x = 5, .y = 5});
}
