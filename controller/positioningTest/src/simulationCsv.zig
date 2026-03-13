const std = @import("std");

const Data = struct {
    time: f32,
    heading: f32,
    accelerationX: f32,
    accelerationY: f32,
    accelerationZ: f32,
    velocity: f32,
    distance: f32,
};

pub const SimulationCsv = struct {
    const Self = @This();

    deltaTime: f32,
    measuredAngularRate: f32,
    measuredVelocity: f32,
    distance: f32,
    velocity: f32,
    heading: f32,

    index: usize,
    trackLength: f32,
    initialDistance: f32,
    steps: []const Data,

    pub fn init(allocator: std.mem.Allocator, filePath: []const u8, trackLength: f32) !Self {
        const file = try std.fs.cwd().openFile(filePath, .{});
        defer file.close();

        var buf: [4096]u8 = undefined;
        var file_reader = file.reader(&buf);

        const reader = &file_reader.interface;

        var steps = try std.ArrayList(Data).initCapacity(allocator, 10);
        _ = try reader.takeDelimiterExclusive('\n');
        reader.toss(1);
        while (reader.takeDelimiterExclusive('\n')) |line| {
            reader.toss(1);

            var iter = std.mem.tokenizeScalar(u8, line, ',');

            const data: Data = .{
                .time = try std.fmt.parseFloat(f32, iter.next().?),
                .heading = try std.fmt.parseFloat(f32, iter.next().?),
                .accelerationX = try std.fmt.parseFloat(f32, iter.next().?),
                .accelerationY = try std.fmt.parseFloat(f32, iter.next().?),
                .accelerationZ = try std.fmt.parseFloat(f32, iter.next().?),
                .velocity = try std.fmt.parseFloat(f32, iter.next().?),
                .distance = try std.fmt.parseFloat(f32, iter.next().?),
            };
            try steps.append(allocator, data);
        } else |err| {
            if (err != error.EndOfStream) return err;
        }

        var self: Self = .{
            .deltaTime = 0.0,
            .measuredAngularRate = 0.0,
            .measuredVelocity = 0.0,
            .distance = 0.0,
            .velocity = 0.0,
            .heading = 0.0,
            .index = 1,
            .trackLength = trackLength,
            .initialDistance = steps.items[0].distance,
            .steps = try steps.toOwnedSlice(allocator),
        };
        self.updateHelper();
        return self;
    }

    pub fn update(self: *Self) void {
        std.debug.print("index: {d}\n", .{self.index});
        self.index = (self.index + 1) % self.steps.len;
        self.updateHelper();
    }

    fn updateHelper(self: *Self) void {
        const current = self.steps[self.index];
        if (self.index != 0) {
            self.deltaTime = current.time - self.steps[self.index - 1].time;
            self.measuredVelocity = (current.distance - self.steps[self.index - 1].distance) / self.deltaTime;
            self.measuredAngularRate = (current.heading - self.steps[self.index - 1].heading) / self.deltaTime;
            self.distance = @mod(current.distance - self.initialDistance, self.trackLength);
            self.heading = current.heading;
            self.velocity = current.velocity;
        }
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.steps);
    }
};
