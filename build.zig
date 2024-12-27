const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = std.Target.Query{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu, .glibc_version = .{ .major = 2, .minor = 36, .patch = 0 } };
    //const target = std.Target.Query.parse(.{ .arch_os_abi = "aarch64-linux-gnu" }) catch unreachable;
    const exe = b.addExecutable(.{
        .name = "asc",
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(target),
        .optimize = optimize,
    });

    exe.addIncludePath(b.path("lib/BNO055_SensorAPI/"));
    exe.addCSourceFile(.{
        .file = b.path("lib/BNO055_SensorAPI/bno055.c"),
        .flags = &[_][]const u8{
            "-fno-sanitize=undefined",
            "-fno-sanitize=shift",
        },
    });

    exe.addIncludePath(b.path("lib/pigpio/"));
    exe.addLibraryPath(b.path("lib/pigpio/"));
    exe.linkSystemLibrary2("pigpio", .{ .preferred_link_mode = .dynamic });
    exe.linkLibC();

    b.installArtifact(exe);

    //const run_cmd = b.addRunArtifact(exe);

    //run_cmd.step.dependOn(b.getInstallStep());

    //if (b.args) |args| {
    //    run_cmd.addArgs(args);
    //}

    //const run_step = b.step("run", "Run the app");
    //run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(.{}),
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
