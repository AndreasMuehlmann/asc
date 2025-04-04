const std = @import("std");

const Point = @import("point.zig").Point;
const quickselect = @import("quickselect.zig").quickselect;


pub const Node = struct {
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

        const pivotIndex: usize = quickselect(points, points.len / 2, dimension);
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
