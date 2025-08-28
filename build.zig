const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = std.Target.Query{
        .cpu_arch = .riscv32,
        .os_tag = .freestanding,
        .abi = .none,
        .cpu_model = .{ .explicit = &std.Target.riscv.cpu.generic_rv32 },
        .cpu_features_add = std.Target.riscv.featureSet(&.{ .m, .c, .zifencei, .zicsr, .i }),
    };

    const clientTarget = b.standardTargetOptions(.{});

    const encodeModule = b.addModule("encode", .{ .root_source_file = b.path("shared/messageFormat/encode.zig") });
    const decodeModule = b.addModule("decode", .{ .root_source_file = b.path("shared/messageFormat/decode.zig") });
    const serverContractModule = b.addModule("encode", .{ .root_source_file = b.path("shared/serverContract.zig") });
    const clientContractModule = b.addModule("decode", .{ .root_source_file = b.path("shared/clientContract.zig") });
    const unitTestsMessageFormat = b.addTest(.{
        .root_source_file = b.path("shared/messageFormat/testEncodeDecode.zig"),
        .target = clientTarget,
    });
    const runUnitTestsMessageFormat = b.addRunArtifact(unitTestsMessageFormat);

    const commandParserModule = b.addModule("commandParser", .{ .root_source_file = b.path("shared/commandParser/commandParser.zig") });

    const unitTestsCommandParser = b.addTest(.{
        .root_source_file = b.path("shared/commandParser/commandParser.zig"),
        .target = clientTarget,
    });
    const runUnitTestsCommandParser = b.addRunArtifact(unitTestsCommandParser);

    const clap = b.dependency("clap", .{});

    const controllerLib = b.addStaticLibrary(.{
        .name = "asc",
        .root_source_file = b.path("controller/main.zig"),
        .target = b.resolveTargetQuery(target),
        .optimize = optimize,
    });

    controllerLib.root_module.addImport("encode", encodeModule);
    controllerLib.root_module.addImport("decode", decodeModule);
    controllerLib.root_module.addImport("serverContract", serverContractModule);
    controllerLib.root_module.addImport("clientContract", clientContractModule);

    controllerLib.root_module.addImport("commandParser", commandParserModule);

    controllerLib.addIncludePath(b.path("controller/"));
    controllerLib.addCSourceFiles(.{ .files = &[_][]const u8{
        "controller/rtos.c",
        "controller/server.c",
        "controller/wifi.c",
    } });

    controllerLib.addIncludePath(b.path("lib/BNO055_SensorAPI/"));
    controllerLib.addCSourceFile(.{
        .file = b.path("lib/BNO055_SensorAPI/bno055.c"),
        .flags = &[_][]const u8{
            "-fno-sanitize=undefined",
            "-fno-sanitize=shift",
        },
    });

    controllerLib.linkLibC();

    std.fs.cwd().access("main/includeDirs.txt", .{}) catch |err| {
        if (err != error.FileNotFound) {
            std.log.err("Unexpected error while trying to check if \"main/includeDirs.txt\" exists: {}.", .{err});
            @panic("Unexpected error while trying to check if \"main/includeDirs.txt\" exists.");
        }
        std.log.info("Running \"idf.py build\" to export \"includeDirs.txt.\"", .{});
        var child = std.process.Child.init(&[_][]const u8{ "idf.py", "build" }, b.allocator);
        child.stdout_behavior = .Inherit;
        child.spawn() catch @panic("Failed to run \"idf.py build\". Maybe you didn't export environment variables with: \". <pathToEspIdf>/export.sh\"");
        const exitCode = child.wait() catch |errChild| {
            std.log.err("Error while waiting for \"idf.py build\": {}.", .{errChild});
            @panic("Failed to wait for \"idf.py build\". Maybe you didn't export environment variables with: \". <pathToEspIdf>/export.sh\"");
        };

        if (exitCode.Exited != 0) {
            @panic("\"idf.py build\" failed with non zero exit code.");
        }
        std.log.info("Succesfully ran \"idf.py build\" to export \"includeDirs.txt.\"", .{});
    };

    const file = std.fs.cwd().openFile("main/includeDirs.txt", .{}) catch @panic("main/includeDirs.txt was not found.");
    const file_contents = file.readToEndAlloc(b.allocator, 100000) catch unreachable;
    var it = std.mem.tokenizeScalar(u8, file_contents, ';');
    while (it.next()) |dir| {
        controllerLib.addIncludePath(.{ .cwd_relative = dir });
    }

    b.installArtifact(controllerLib);

    const clientExe = b.addExecutable(.{
        .name = "client",
        .root_source_file = b.path("client/main.zig"),
        .target = clientTarget,
        .optimize = optimize,
    });

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = clientTarget,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib");
    const raygui = raylib_dep.module("raygui");
    const raylib_artifact = raylib_dep.artifact("raylib");
    clientExe.linkLibrary(raylib_artifact);
    clientExe.root_module.addImport("raylib", raylib);
    clientExe.root_module.addImport("raygui", raygui);

    clientExe.root_module.addImport("encode", encodeModule);
    clientExe.root_module.addImport("decode", decodeModule);
    clientExe.root_module.addImport("serverContract", serverContractModule);
    clientExe.root_module.addImport("clientContract", clientContractModule);
    clientExe.root_module.addImport("clap", clap.module("clap"));

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
        .target = clientTarget,
    });
    const runUnitTestsClient = b.addRunArtifact(unitTestsClient);

    const testStep = b.step("test", "Run unit tests");
    testStep.dependOn(&runUnitTestsClient.step);
    testStep.dependOn(&runUnitTestsMessageFormat.step);
    testStep.dependOn(&runUnitTestsCommandParser.step);

    const idfBuildCmd = b.addSystemCommand(&[_][]const u8{"idf.py"});
    idfBuildCmd.addArg("build");

    const buildIdfStep = b.step("buildIdf", "Build the zig library and the final image.");
    buildIdfStep.dependOn(b.getInstallStep());
    buildIdfStep.dependOn(&idfBuildCmd.step);

    const flashCmd = b.addSystemCommand(&[_][]const u8{"idf.py"});
    flashCmd.addArg("flash");
    flashCmd.step.dependOn(buildIdfStep);

    const flashStep = b.step("flash", "Build the zig library, the final image and flash the image onto the esp.");
    flashStep.dependOn(buildIdfStep);
    flashStep.dependOn(&flashCmd.step);
}
