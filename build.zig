const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = std.Target.Query{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu, .glibc_version = .{ .major = 2, .minor = 36, .patch = 0 } };

    const encodeModule = b.addModule("encode", .{ .root_source_file = b.path("shared/messageFormat/encode.zig") });
    const decodeModule = b.addModule("decode", .{ .root_source_file = b.path("shared/messageFormat/decode.zig") });

    const unitTestsMessageFormat = b.addTest(.{
        .root_source_file = b.path("shared/messageFormat/testEncodeDecode.zig"),
        .target = b.resolveTargetQuery(.{}),
    });
    const runUnitTestsMessageFormat = b.addRunArtifact(unitTestsMessageFormat);

    const controllerExe = b.addExecutable(.{
        .name = "asc",
        .root_source_file = b.path("controller/main.zig"),
        .target = b.resolveTargetQuery(target),
        .optimize = optimize,
    });

    controllerExe.root_module.addImport("encode", encodeModule);
    controllerExe.root_module.addImport("decode", decodeModule);

    controllerExe.addIncludePath(b.path("lib/BNO055_SensorAPI/"));
    controllerExe.addCSourceFile(.{
        .file = b.path("lib/BNO055_SensorAPI/bno055.c"),
        .flags = &[_][]const u8{
            "-fno-sanitize=undefined",
            "-fno-sanitize=shift",
        },
    });

    controllerExe.addIncludePath(b.path("lib/pigpio/"));
    controllerExe.addLibraryPath(b.path("lib/pigpio/"));
    controllerExe.linkSystemLibrary2("pigpio", .{ .preferred_link_mode = .dynamic });
    controllerExe.linkLibC();

    b.installArtifact(controllerExe);

    const scpCmd = b.addSystemCommand(&[_][]const u8{"scp"});
    scpCmd.addArtifactArg(controllerExe);
    scpCmd.addArg("asc@raspberrypi.fritz.box:/home/asc/asc");

    const customInstallStep = b.step("deploy", "Copying the controller executable onto the raspberry pi with scp.");
    customInstallStep.dependOn(b.getInstallStep());
    customInstallStep.dependOn(&scpCmd.step);

    const unitTestsController = b.addTest(.{
        .root_source_file = b.path("controller/main.zig"),
        .target = b.resolveTargetQuery(.{}),
    });
    const runUnitTestsController = b.addRunArtifact(unitTestsController);

    const clientExe = b.addExecutable(.{
        .name = "client",
        .root_source_file = b.path("client/main.zig"),
        .target = b.resolveTargetQuery(.{}),
        .optimize = optimize,
    });

    clientExe.root_module.addImport("encode", encodeModule);
    clientExe.root_module.addImport("decode", decodeModule);

    b.installArtifact(clientExe);

    const runClientCmd = b.addRunArtifact(clientExe);
    runClientCmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        runClientCmd.addArgs(args);
    }

    const runClientStep = b.step("runClient", "Run the client");
    runClientStep.dependOn(&runClientCmd.step);

    const unitTestsClient = b.addTest(.{
        .root_source_file = b.path("client/main.zig"),
        .target = b.resolveTargetQuery(.{}),
    });
    const runUnitTestsClient = b.addRunArtifact(unitTestsClient);

    const testStep = b.step("test", "Run unit tests");
    testStep.dependOn(&runUnitTestsController.step);
    testStep.dependOn(&runUnitTestsClient.step);
    testStep.dependOn(&runUnitTestsMessageFormat.step);

    const deployRunClientStep = b.step("deployRunClient", "Run the client and deploy the controller");
    deployRunClientStep.dependOn(&runClientCmd.step);
    deployRunClientStep.dependOn(&scpCmd.step);
}
