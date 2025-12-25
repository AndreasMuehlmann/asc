const std = @import("std");

const rl = @import("raylib");

pub fn headingToPosition(points: *[]rl.Vector2, averageVelocity: f32) void {
    if (points.len == 0) {
        return;
    }
    var prevTime = points.*[0].x;
    var prevHeading = points.*[0].y;
    points.*[0] = rl.Vector2.init(0, 0);
    for (1..points.len) |i| {
        const deltaTime: f32 = points.*[i].x - prevTime;

        const distance = averageVelocity * deltaTime;
        prevTime = points.*[i].x;
        const newHeading = points.*[i].y;

        const adjustmentForCurve: f32 = std.math.pow(f32, std.math.e, -@abs(newHeading - prevHeading) / 35);
        points.*[i] = .{
            .x = points.*[i - 1].x + -std.math.cos(prevHeading * 180.0 / std.math.pi) * distance * adjustmentForCurve,
            .y = points.*[i - 1].y + std.math.sin(prevHeading * 180.0 / std.math.pi) * distance * adjustmentForCurve,
        };
        prevHeading = newHeading;
    }
}
