const std = @import("std");

const Point = struct {
    x: f64,
    y: f64,

    const Self = @This();

    fn getDimension(self: Self, dimension: usize) f64 {
        if (dimension == 0) {
            return self.x;
        } else if (dimension == 1) {
            return self.y;
        }
        unreachable;
    }
};

fn swap(comptime T: type, first: *T, second: *T) void {
    const temp = first.*;
    first.* = second.*;
    second.* = temp;
}

fn partition(points: []Point, dimension: usize) usize {
    const pivot: f64 = points[points.len - 1].getDimension(dimension);
    var i: usize = 0;

    for (i..points.len - 1) |j| {
        if (points[j].getDimension(dimension) <= pivot) {
            swap(Point, &points[i], &points[j]);
            i += 1;
        }
    }
    swap(Point, &points[i], &points[points.len - 1]);
    return i;
}

fn quickselect(points: []Point, k: usize, dimension: usize) usize {
    var left: usize = 0;
    var right: usize = points.len - 1;
    while (true) {
        if (left == right) {
            return left;
        }
        const pivotIndex: usize = left + partition(points[left .. right + 1], dimension);
        if (pivotIndex == k) {
            return k;
        } else if (k < pivotIndex) {
            right = pivotIndex - 1;
        } else {
            left = pivotIndex + 1;
        }
    }
}

const testing = std.testing;

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
    const pivotIndex = partition(&points, 0);
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
    const medianIndex = quickselect(&points, @divTrunc(points.len, 2), 0);
    try testing.expectEqual(4, medianIndex);
    try testing.expectEqual(4, points[medianIndex].x);
}

test "kdTreeWithExpectedStructure" {}
