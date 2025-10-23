const std = @import("std");
const sokol = @import("sokol");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dep_sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });
    const dep_zstbi = b.dependency("zstbi", .{});
    const dep_shdc = dep_sokol.builder.dependency("shdc", .{});
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "sokol",
                .module = dep_sokol.module("sokol"),
            },
            .{
                .name = "zstbi",
                .module = dep_zstbi.module("root"),
            },
        },
    });
    const exe = b.addExecutable(.{
        .name = "mage_game",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    try buildShader(b, dep_shdc, run_step, "display");
    try buildShader(b, dep_shdc, run_step, "sprites");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

fn buildShader(b: *std.Build, dep_shdc: *std.Build.Dependency, run_step: *std.Build.Step, shader_name: []const u8) !void {
    const shader_dir = "src/shaders";
    const shdc_step = try sokol.shdc.createSourceFile(b, .{
        .shdc_dep = dep_shdc,
        .input = b.fmt("{s}/{s}.glsl", .{ shader_dir, shader_name }),
        .output = b.fmt("{s}/{s}.zig", .{ shader_dir, shader_name }),
        .slang = .{ .glsl430 = true },
    });
    run_step.dependOn(shdc_step);
}
