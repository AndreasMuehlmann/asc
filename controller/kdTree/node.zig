const std = @import("std");


pub fn Node(comptime pointT: type, comptime dimesions: usize) type {
    return struct {
        const Self = @This();

        point: pointT,
        left: ?*Self,
        right: ?*Self,
        splittingDimension: usize,

        fn getDimension(self: Self) f64 {
            return self.point.getDimension(self.splittingDimension);
        }

        pub fn initSubTree(allocator: std.mem.Allocator, points: []pointT, dimension: usize) !?*Self {
            if (points.len == 0) {
                return null;
            }
            const node: *Self = try allocator.create(Self);
            if (points.len == 1) {
                node.point = points[0];
                node.left = null;
                node.right = null;
                node.splittingDimension = dimension;
                return node;
            }

            const pivotIndex: usize = Self.quickselect(points, points.len / 2, dimension);
            const newDimension = (dimension + 1) % dimesions;
            node.point = points[pivotIndex];
            node.left = try Self.initSubTree(allocator, points[0..pivotIndex], newDimension);
            node.right = try Self.initSubTree(allocator, points[pivotIndex + 1 ..], newDimension);
            node.splittingDimension = dimension;
            return node;
        }

        pub fn insert(self: *Self, node: *Self) void {
            node.splittingDimension = (node.splittingDimension + 1) % dimesions;
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

        pub fn nearestNeighbor(self: Self, point: pointT) pointT {
            const treeValue: f64 = self.getDimension();
            const value: f64 = point.getDimension(self.splittingDimension);

            var nn: pointT = self.point;
            var otherSubtree: ?*Self = null;

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
                    const nnOtherSubtree: pointT = node.nearestNeighbor(point);
                    if (point.calcSquaredDistance(nnOtherSubtree) < point.calcSquaredDistance(nn)) {
                        nn = nnOtherSubtree;
                    }
                }
            }

            return nn;
        }

        pub fn print(self: Self, allocator: std.mem.Allocator, id: usize) !usize {
            const stdout = std.io.getStdOut().writer();
            var arrayList = std.ArrayList(u8).init(allocator);
            defer arrayList.deinit();
            try arrayList.appendSlice("    ");
            const bu = try std.fmt.allocPrint(allocator, "{d}", .{id});
            defer allocator.free(bu);

            try arrayList.appendSlice(bu);
            try arrayList.appendSlice(" [label = \"(");

            const b = try std.fmt.allocPrint(allocator, "{d:.1}", .{self.point.getDimension(0)});
            defer allocator.free(b);
            try arrayList.appendSlice(b);
            for (1..dimesions) |i| {
                const buf = try std.fmt.allocPrint(allocator, ", {d:.1}", .{self.point.getDimension(i)});
                defer allocator.free(buf);
                try arrayList.appendSlice(buf);
            }
            try arrayList.appendSlice(") ");
            const buf = try std.fmt.allocPrint(allocator, "{d}", .{self.splittingDimension});
            defer allocator.free(buf);
            try arrayList.appendSlice(buf);
            try arrayList.appendSlice("\"];\n");
            try stdout.writeAll(arrayList.items);
            var subTreeSize: usize = 1;
            if (self.left) |l| {
                const buffer = try std.fmt.allocPrint(allocator, "    {d} -> {d};\n", .{id, id + 1});
                defer allocator.free(buffer);
                try stdout.writeAll(buffer);

                subTreeSize += try l.print(allocator, id + 1);
            }
            if (self.right) |r| {
                const buffer = try std.fmt.allocPrint(allocator, "    {d} -> {d};\n", .{id, id + subTreeSize});
                defer allocator.free(buffer);
                try stdout.writeAll(buffer);
                subTreeSize += try r.print(allocator, id + subTreeSize);
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

        fn partition(points: []pointT, dimension: usize) usize {
            const pivot: f64 = points[points.len - 1].getDimension(dimension);
            var i: usize = 0;

            for (i..points.len - 1) |j| {
                if (points[j].getDimension(dimension) <= pivot) {
                    swap(pointT, &points[i], &points[j]);
                    i += 1;
                }
            }
            swap(pointT, &points[i], &points[points.len - 1]);
            return i;
        }

        pub fn quickselect(points: []pointT, k: usize, dimension: usize) usize {
            var left: usize = 0;
            var right: usize = points.len - 1;
            while (true) {
                if (left == right) {
                    return left;
                }
                const pivotIndex: usize = left + Self.partition(points[left .. right + 1], dimension);
                if (pivotIndex == k) {
                    return k;
                } else if (k < pivotIndex) {
                    right = pivotIndex - 1;
                } else {
                    left = pivotIndex + 1;
                }
            }
        }
    };
}

fn swap(comptime T: type, first: *T, second: *T) void {
    const temp = first.*;
    first.* = second.*;
    second.* = temp;
}


const testing = std.testing;
const Point = @import("point.zig").Point;

test "partition" {
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
    const pivotIndex = Node(Point, 2).partition(&points, 0);
    try testing.expectEqual(6, pivotIndex);
    try testing.expect((points[8].x == 20 or points[7].x == 20) and (points[8].x == 9 or points[7].x == 9));
}

test "quickselect" {
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
    const medianIndex = Node(Point, 2).quickselect(&points, @divTrunc(points.len, 2), 0);
    try testing.expectEqual(4, medianIndex);
    try testing.expectEqual(4, points[medianIndex].x);
}
