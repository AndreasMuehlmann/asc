pub fn vectorMultiply(
    comptime R: usize,
    comptime C: usize,
    a: [R][C]f32,
    x: [C]f32,
) [R]f32 {
    var y: [R]f32 = undefined;

    for (0..R) |i| {
        var sum: f32 = 0.0;
        for (0..C) |j| {
            sum += a[i][j] * x[j];
        }
        y[i] = sum;
    }
    return y;
}

pub fn multiply(
    comptime R: usize,
    comptime M: usize,
    comptime C: usize,
    a: [R][M]f32,
    b: [M][C]f32,
) [R][C]f32 {
    var result: [R][C]f32 = undefined;

    for (0..R) |i| {
        for (0..C) |j| {
            var sum: f32 = 0.0;
            for (0..M) |k| {
                sum += a[i][k] * b[k][j];
            }
            result[i][j] = sum;
        }
    }
    return result;
}

pub fn addWithCoefficients(
    comptime R: usize,
    comptime C: usize,
    aCoefficient: f32,
    bCoefficient: f32,
    a: [R][C]f32,
    b: [R][C]f32,
) [R][C]f32 {
    var result: [R][C]f32 = undefined;

    for (0..R) |i| {
        for (0..C) |j| {
            result[i][j] = aCoefficient * a[i][j] + bCoefficient * b[i][j];
        }
    }

    return result;
}

pub fn transpose2D(a: [2][2]f32) [2][2]f32 {
    return .{
        .{ a[0][0], a[1][0] },
        .{ a[0][1], a[1][1] },
    };
}

pub fn inverse2D(a: [2][2]f32) [2][2]f32 {
    const det = a[0][0] * a[1][1] - a[0][1] * a[1][0];
    return .{
        .{ a[1][1] / det, -a[0][1] / det },
        .{ -a[1][0] / det, a[0][0] / det },
    };
}
