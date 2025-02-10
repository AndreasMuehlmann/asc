const std = @import("std");

const Controller = @import("controller.zig").Controller;

const esp = @cImport({
    @cInclude("esp_system.h");
});

//TODO: overwrite panic
//TODO: implement networking
//TODO: get controller to work again

export fn app_main() void {
    const allocator = std.heap.raw_c_allocator;
    const slice = allocator.alloc(u8, 5) catch unreachable;
    defer allocator.free(slice);

    var controller = Controller.init(allocator) catch unreachable;
    defer controller.deinit();
    controller.run() catch unreachable;

    esp.esp_restart();
}

//
//   const os = std.os;
//
//   // const NetServer = @import("netServer.zig").NetServer;
//
//   const clientContract = @import("clientContract");
//   const serverContract = @import("serverContract");
//
//   const esp = @cImport({
//       @cInclude("sdkconfig.h");
//       @cInclude("esp_err.h");
//       @cInclude("esp_log.h");
//       @cInclude("esp_system.h");
//   });
//
//   const c = @cImport(@cInclude("stdio.h"));
//
//   export fn app_main() void {

//       //const params = comptime clap.parseParamsComptime(
//       //    \\-h, --help            Display this help and exit.
//       //    \\-p, --port <u16>      Port for the server.
//       //);
//
//       //var diag = clap.Diagnostic{};
//       //var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
//       //    .diagnostic = &diag,
//       //    .allocator = gpa.allocator(),
//       //}) catch |err| {
//       //    diag.report(std.io.getStdErr().writer(), err) catch {};
//       //    return;
//       //};
//       //defer res.deinit();
//
//       //if (res.args.help != 0)
//       //    return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
//
//       //if (pigpio.gpioInitialise() < 0) {
//       //    std.log.err("Failure in gpioInitialise.\n", .{});
//       //    return error.PigpioInitialization;
//       //}
//       //defer pigpio.gpioTerminate();
//
//       //const act = os.linux.Sigaction{
//       //    .handler = .{ .handler = sigIntHandler },
//       //    .mask = os.linux.empty_sigset,
//       //    .flags = 0,
//       //};
//
//       //if (os.linux.sigaction(os.linux.SIG.INT, &act, null) != 0) {
//       //    return error.SignalHandlerCreation;
//       //}
//
//       //var port: u16 = 8080;
//       //if (res.args.port) |argPort| {
//       //    port = argPort;
//       //}
//       //const netServer = try NetServer(serverContract.ServerContractEnum, serverContract.ServerContract, Controller, clientContract.ClientContract).init(
//       //    gpa.allocator(),
//       //    port,
//       //    &controller,
//       //);
//
//       _ = c.printf("Hello world!\n");
//       esp.esp_restart();
//
//   }
