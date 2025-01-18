const std = @import("std");
const net = std.net;

const NetClient = @import("netClient.zig").NetClient;
const clientContract = @import("clientContract");

pub const Client = struct {
    allocator: std.mem.Allocator,
    file: std.fs.File,
    netClient: NetClient(clientContract.ClientContractEnum, clientContract.ClientContract, Self),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, netClient: NetClient(clientContract.ClientContractEnum, clientContract.ClientContract, Self)) !Self {
        const file = try std.fs.cwd().createFile("measurements.csv", .{ .truncate = true });
        try file.writeAll("time,heading,roll,pitch\n");

        return .{ .allocator = allocator, .file = file, .netClient = netClient };
    }

    pub fn run(self: *Self) !void {
        while (true) {
            try self.netClient.recv();
        }
    }

    pub fn deinit(self: Self) void {
        self.netClient.deinit();
        self.file.close();
    }

    pub fn handleOrientation(self: *Self, orientation: clientContract.Orientation) !void {
        std.debug.print("{d},{d},{d},{d}\n", .{ orientation.time, orientation.heading, orientation.roll, orientation.pitch });
        const message = try std.fmt.allocPrint(self.allocator, "{d},{d},{d},{d}\n", .{ orientation.time, orientation.heading, orientation.roll, orientation.pitch });
        try self.file.writeAll(message);
        self.allocator.free(message);
    }
};
