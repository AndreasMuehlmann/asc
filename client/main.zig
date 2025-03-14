const std = @import("std");
const os = std.os;

const Client = @import("client.zig").Client;
const NetClient = @import("netClient.zig").NetClient;
const clientContract = @import("clientContract");
const serverContract = @import("serverContract");
const commandParserMod = @import("commandParser");
const CommandParser = commandParserMod.CommandParser;

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

const ascclient = struct {
    server: []const u8 = "espressif.fritz.box",
    port: u16 = 8080,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const act = os.linux.Sigaction{
        .handler = .{ .handler = sigIntHandler },
        .mask = os.linux.empty_sigset,
        .flags = 0,
    };

    if (os.linux.sigaction(os.linux.SIG.INT, &act, null) != 0) {
        return error.SignalHandlerCreation;
    }

    const descriptions: []const commandParserMod.FieldDescription = &.{
        .{ .fieldName = "ssid", .description = "The name of the wlan to connect to." },
        .{ .fieldName = "password", .description = "The passowrd for the wlan to connect to." },
    };

    var commandStrList = std.ArrayList(u8).init(gpa.allocator());
    defer commandStrList.deinit();

    var argsIterator = std.process.args();
    defer argsIterator.deinit();

    _ = argsIterator.next();
    try commandStrList.appendSlice("ascclient");
    while (argsIterator.next()) |arg| {
        try commandStrList.append(' ');
        try commandStrList.appendSlice(arg);
    }
    const commandStr = try commandStrList.toOwnedSlice();
    defer gpa.allocator().free(commandStr);

    const commandParserT: type = CommandParser(ascclient, descriptions);
    var commandParser = commandParserT.init(gpa.allocator(), commandStr);
    defer commandParser.deinit();
    const command = commandParser.parse() catch {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("{s}\n", .{commandParser.message});
        return;
    };
    std.debug.print("{s}, {d}\n", .{ command.server, command.port });

    const netClient = try NetClient(clientContract.ClientContractEnum, clientContract.ClientContract, Client, serverContract.ServerContract).init(
        gpa.allocator(),
        command.server,
        command.port,
        &client,
    );
    client = try Client.init(gpa.allocator(), netClient);
    isClientCreated = true;
    defer client.deinit();

    try client.run();
}
