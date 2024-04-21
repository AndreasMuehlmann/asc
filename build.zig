const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = std.zig.CrossTarget{
            .cpu_arch = std.Target.Cpu.Arch.arm,
            .os_tag = std.Target.Os.Tag.linux,
            .abi = std.Target.Abi.gnueabi,
        },
    });
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "asc",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibC();
    exe.addIncludePath(.{ .path = "/home/andi/programming/asc/libs/pigpio" });
    exe.addLibraryPath(.{ .path = "/home/andi/programming/asc/cross_compiled_libs/pigpio/" });
    exe.linkSystemLibrary("pigpio");
    b.installArtifact(exe);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = std.zig.CrossTarget{},
        .optimize = optimize,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const argv = [_][]const u8{"./deploy_raspi.sh"};
    const deploy = b.addSystemCommand(&argv);
    deploy.step.dependOn(b.getInstallStep());
    const deploy_step = b.step("deploy", "Deploy the executable on the raspberry pi");
    deploy_step.dependOn(&deploy.step);
}
