const std = @import("std");
const os = std.os;

const pigpio = @cImport(@cInclude("pigpio.h"));
const clap = @import("clap");
const Controller = @import("controller.zig").Controller;
const NetServer = @import("netServer.zig").NetServer;

const clientContract = @import("clientContract");
const serverContract = @import("serverContract");

var controller: Controller = undefined;
var isControllerCreated: bool = false;

pub fn sigIntHandler(sig: c_int) callconv(.C) void {
    _ = sig;

    std.log.warn("Received signal to exit.\n", .{});

    if (isControllerCreated) {
        controller.deinit();
    }
    pigpio.gpioTerminate();

    std.process.exit(1);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help            Display this help and exit.
        \\-p, --port <u16>      Port for the server.
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

    if (pigpio.gpioInitialise() < 0) {
        std.log.err("Failure in gpioInitialise.\n", .{});
        return error.PigpioInitialization;
    }
    defer pigpio.gpioTerminate();

    const act = os.linux.Sigaction{
        .handler = .{ .handler = sigIntHandler },
        .mask = os.linux.empty_sigset,
        .flags = 0,
    };

    if (os.linux.sigaction(os.linux.SIG.INT, &act, null) != 0) {
        return error.SignalHandlerCreation;
    }

    var port: u16 = 8080;
    if (res.args.port) |argPort| {
        port = argPort;
    }
    const netServer = try NetServer(serverContract.ServerContractEnum, serverContract.ServerContract, Controller, clientContract.ClientContract).init(
        gpa.allocator(),
        port,
        &controller,
    );

    controller = try Controller.init(gpa.allocator(), netServer);
    isControllerCreated = true;
    defer controller.deinit();

    try controller.run();
}
