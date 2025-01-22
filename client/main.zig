const std = @import("std");
const os = std.os;

const clap = @import("clap");

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
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help            Display this help and exit.
        \\-s, --server <str>    Hostname of the server to connect to.
        \\-p, --port <u16>      Port of the server to connect to.
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = gpa.allocator(),
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return;
    };
    defer res.deinit();

    if (res.args.help != 0)
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});

    const act = os.linux.Sigaction{
        .handler = .{ .handler = sigIntHandler },
        .mask = os.linux.empty_sigset,
        .flags = 0,
    };

    if (os.linux.sigaction(os.linux.SIG.INT, &act, null) != 0) {
        return error.SignalHandlerCreation;
    }
    var hostname: []const u8 = "raspberrypi.fritz.box";
    if (res.args.server) |argHostname| {
        hostname = argHostname;
    }
    var port: u16 = 8080;
    if (res.args.port) |argPort| {
        port = argPort;
    }
    const netClient = try NetClient(clientContract.ClientContractEnum, clientContract.ClientContract, Client, serverContract.ServerContract).init(
        gpa.allocator(),
        hostname,
        port,
        &client,
    );
    client = try Client.init(gpa.allocator(), netClient);
    isClientCreated = true;
    defer client.deinit();

    try client.run();
}
