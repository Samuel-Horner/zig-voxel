const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Make executable
    const exe = b.addExecutable(.{
        .name = "zig_voxel",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // System Libraries
    exe.linkLibC();

    // Zigglen
    const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"4.6",
        .profile = .core,
        .extensions = &.{},
    });
    exe.root_module.addImport("gl", gl_bindings);

    // Zig-GLFW
    const glfw_dep = b.dependency("glfw", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("glfw", glfw_dep.module("glfw"));

    // Mach FreeType
    const mach_freetype = b.dependency("mach_freetype", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("freetype", mach_freetype.module("mach-freetype"));

    // // CGLM https://github.com/lilydoar/cglm
    // const cglm_dep = b.dependency("cglm", .{
    //     .target = target,
    //     .optimize = optimize,
    //     .static = true,
    //     .shared = false
    // });
    // exe.linkLibrary(cglm_dep.artifact("cglm"));
    // exe.addIncludePath(cglm_dep.path("include"));

    // ZM https://github.com/griush/zm
    const zm_dep = b.dependency("zm", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zm", zm_dep.module("zm"));

    // ZNoise
    const znoise_dep = b.dependency("znoise", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("znoise", znoise_dep.module("root"));
    exe.linkLibrary(znoise_dep.artifact("FastNoiseLite"));

    b.installArtifact(exe);

    { // Run step
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }

    { // Test step
        const exe_unit_tests = b.addTest(.{
            .root_module = exe.root_module,
        });

        const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_exe_unit_tests.step);
    }

    { // RenderDoc step
        const render_doc_step = b.step("renderdoc", "Runs the app in renderdoc");
        render_doc_step.dependOn(b.getInstallStep());

        const render_doc_cmd = b.addSystemCommand(&.{ "renderdoccmd", "capture" });
        render_doc_cmd.addFileArg(exe.getEmittedBin());

        if (b.args) |args| {
            render_doc_cmd.addArgs(args);
        }

        render_doc_step.dependOn(&render_doc_cmd.step);
    }
}
