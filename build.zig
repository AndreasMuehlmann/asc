const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = std.Target.Query.parse(.{ .arch_os_abi = "aarch64-linux-gnu" }) catch unreachable;
    const exe = b.addExecutable(.{
        .name = "asc",
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(target),
        .optimize = optimize,
    });

    const zigpio = b.addModule(
        "zigpio",
        .{
            .root_source_file = b.path("src/zigpio/zigpio.zig"),
        },
    );
    exe.root_module.addImport("zigpio", zigpio);
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
