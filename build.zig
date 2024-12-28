const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = std.Target.Query{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu, .glibc_version = .{ .major = 2, .minor = 36, .patch = 0 } };

    const controllerExe = b.addExecutable(.{
        .name = "asc",
        .root_source_file = b.path("controller/main.zig"),
        .target = b.resolveTargetQuery(target),
        .optimize = optimize,
    });

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

    const scp_cmd = b.addSystemCommand(&[_][]const u8{"scp"});
    scp_cmd.addArtifactArg(controllerExe);
    scp_cmd.addArg("asc@raspberrypi.fritz.box:/home/asc/asc");

    const custom_install_step = b.step("deploy", "Copying the controller executable onto the raspberry pi with scp.");
    custom_install_step.dependOn(b.getInstallStep());
    custom_install_step.dependOn(&scp_cmd.step);

    const unit_tests_controller = b.addTest(.{
        .root_source_file = b.path("controller/main.zig"),
        .target = b.resolveTargetQuery(.{}),
    });
    const run_unit_tests_controller = b.addRunArtifact(unit_tests_controller);

    const clientExe = b.addExecutable(.{
        .name = "client",
        .root_source_file = b.path("client/main.zig"),
        .target = b.resolveTargetQuery(.{}),
        .optimize = optimize,
    });

    b.installArtifact(clientExe);

    const run_client_cmd = b.addRunArtifact(clientExe);
    run_client_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_client_cmd.addArgs(args);
    }

    const run_client_step = b.step("runClient", "Run the client");
    run_client_step.dependOn(&run_client_cmd.step);

    const unit_tests_client = b.addTest(.{
        .root_source_file = b.path("client/main.zig"),
        .target = b.resolveTargetQuery(.{}),
    });
    const run_unit_tests_client = b.addRunArtifact(unit_tests_client);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests_controller.step);
    test_step.dependOn(&run_unit_tests_client.step);

    const deploy_run_client_step = b.step("deployRunClient", "Run the client and deploy the controller");
    deploy_run_client_step.dependOn(&run_client_cmd.step);
    deploy_run_client_step.dependOn(&scp_cmd.step);
}
