const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = std.Target.Query{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu, .glibc_version = .{ .major = 2, .minor = 36, .patch = 0 } };
    const exe = b.addExecutable(.{
        .name = "icm20948",
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(target),
        .optimize = optimize,
    });

    exe.addIncludePath(b.path("../../lib/pigpio/"));
    exe.addLibraryPath(b.path("../../lib/pigpio/"));
    exe.linkSystemLibrary2("pigpio", .{ .preferred_link_mode = .dynamic });
    exe.linkLibC();

    b.installArtifact(exe);

    const scpCmd = b.addSystemCommand(&[_][]const u8{"scp"});
    scpCmd.addArtifactArg(exe);
    scpCmd.addArg("asc@raspberrypi.fritz.box:/home/asc/asc_test/icm20948");

    const customInstallStep = b.step("deploy", "Copying the exe onto the raspberry pi with scp.");
    customInstallStep.dependOn(b.getInstallStep());
    customInstallStep.dependOn(&scpCmd.step);
}
