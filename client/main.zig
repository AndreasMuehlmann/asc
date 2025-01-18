const std = @import("std");
const os = std.os;

const Client = @import("client.zig").Client;
const NetClient = @import("netClient.zig").NetClient;
const clientContract = @import("clientContract");
const serverContract = @import("serverContract");

var client: Client = undefined;
var isClientCreated: bool = false;

pub fn sigIntHandler(sig: c_int) callconv(.C) void {
    _ = sig;

    std.log.warn("Received signal to exit.\n", .{});

    if (isClientCreated) {
        client.deinit();
    }

    std.process.exit(1);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const act = os.linux.Sigaction{
        .handler = .{ .handler = sigIntHandler },
        .mask = os.linux.empty_sigset,
        .flags = 0,
    };

    if (os.linux.sigaction(os.linux.SIG.INT, &act, null) != 0) {
        return error.SignalHandlerCreation;
    }

    const netClient = try NetClient(clientContract.ClientContractEnum, clientContract.ClientContract, Client, serverContract.ServerContract).init(
        allocator,
        "raspberrypi.fritz.box",
        8080,
        &client,
    );
    client = try Client.init(allocator, netClient);
    isClientCreated = true;
    defer client.deinit();

    try client.run();
}
