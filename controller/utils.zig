const c = @cImport({
    @cInclude("sys/time.h");
});

pub fn timestampMicros() i64 {
    var now = c.timeval{ .tv_sec = 0, .tv_usec = 0 };
    _ = c.gettimeofday(&now, null);
    const seconds: i64 = @intCast(now.tv_sec);
    const micros: i64 = @intCast(now.tv_usec);
    return seconds * 1000000 + micros;
}
