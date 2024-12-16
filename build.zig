const std = @import("std");
const zemscripten = @import("zemscripten");

const Options = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
};

pub fn build(b: *std.Build) !void {
    const project_name = "zig-invaders";
    const options = Options{
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    };

    // When compiling for WASM, make sure to set `sysroot` before raylib
    // dependency is loaded.
    if (options.target.result.isWasm()) {
        b.sysroot = zemscripten.emsdkPath(b);
    }

    // Dependencies
    const raylib_dep = b.dependency("raylib-zig", options);
    const entt_dep = b.dependency("entt", options);
    const zalgebra_dep = b.dependency("zalgebra", options);

    // WASM build
    if (options.target.result.isWasm()) {
        const install_dir = "web";
        const zemscripten_dep = b.dependency("zemscripten", .{});
        const activate_emsdk_step = zemscripten.activateEmsdkStep(b, "3.1.70");

        const wasm = b.addStaticLibrary(.{
            .name = project_name,
            .root_source_file = b.path("src/main.zig"),
            .target = options.target,
            .optimize = options.optimize,
        });

        // Add dependencies to wasm library.
        wasm.root_module.addImport("zemscripten", zemscripten_dep.module("root"));
        wasm.root_module.addImport("raylib", raylib_dep.module("raylib"));
        wasm.linkLibrary(raylib_dep.artifact("raylib"));
        wasm.root_module.addImport("entt", entt_dep.module("zig-ecs"));
        wasm.root_module.addImport("zalgebra", zalgebra_dep.module("zalgebra"));

        var emcc_flags = zemscripten.emccDefaultFlags(b.allocator, options.optimize);
        var emcc_settings = zemscripten.emccDefaultSettings(b.allocator, .{ .optimize = options.optimize });
        const optimiztion_flag = switch (options.optimize) {
            .Debug => "-Og",
            .ReleaseFast => "-Ofast",
            .ReleaseSmall => "-Os",
            else => "-O3",
        };
        // Add optimization flag.
        try emcc_flags.put(optimiztion_flag, {});
        // Raylib requires some of the following settings to be set in order to
        // successfully compile for WASM.
        try emcc_settings.put("ALLOW_MEMORY_GROWTH", "1");
        try emcc_settings.put("FULL-ES3", "1");
        try emcc_settings.put("USE_GLFW", "3");
        try emcc_settings.put("ASYNCIFY", "1");
        try emcc_settings.put("USE_OFFSET_CONVERTER", "1");
        const emcc_step = zemscripten.emccStep(
            b,
            wasm,
            .{
                .optimize = options.optimize,
                .flags = emcc_flags,
                .settings = emcc_settings,
                .use_preload_plugins = true,
                .embed_paths = &.{},
                .preload_paths = &.{.{ .src_path = "assets/" }},
                .install_dir = .{ .custom = install_dir },
            },
        );
        emcc_step.dependOn(activate_emsdk_step);
        b.getInstallStep().dependOn(emcc_step);

        const emrun_args = .{};
        const emrun_step = zemscripten.emrunStep(
            b,
            b.getInstallPath(.{ .custom = install_dir }, project_name ++ ".html"),
            &emrun_args,
        );
        emrun_step.dependOn(emcc_step);
        b.step("emrun", "Build and open the web app locally using emrun").dependOn(emrun_step);
    } else {
        const exe = b.addExecutable(.{
            .name = project_name,
            .root_source_file = b.path("src/main.zig"),
            .target = options.target,
            .optimize = options.optimize,
            .link_libc = true, // libc is required by raylib
        });
        b.installArtifact(exe);

        // Add dependencies to the executable.
        exe.root_module.addImport("raylib", raylib_dep.module("raylib"));
        exe.linkLibrary(raylib_dep.artifact("raylib"));
        exe.root_module.addImport("entt", entt_dep.module("zig-ecs"));
        exe.root_module.addImport("zalgebra", zalgebra_dep.module("zalgebra"));

        // Run executable.
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);

        // Declare executable tests.
        const exe_unit_tests = b.addTest(.{
            .root_source_file = b.path("src/main.zig"),
            .target = options.target,
            .optimize = options.optimize,
        });
        const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

        // Run tests.
        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_exe_unit_tests.step);
    }
}
