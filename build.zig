const std = @import("std");
const bld = @import("std").build;

pub fn buildSokol(b: *bld.Builder, comptime prefix_path: []const u8) *bld.LibExeObjStep {
    const lib = b.addStaticLibrary("sokol", null);
    lib.linkLibC();
    lib.setBuildMode(b.standardReleaseOptions());
    const sokol_path = prefix_path ++ "src/sokol/c/";
    const csources = [_][]const u8 {
        "sokol_app.c",
        "sokol_gfx.c",
        "sokol_time.c",
        "sokol_audio.c",
        "sokol_gl.c",
        "sokol_debugtext.c",
        "sokol_shape.c",
    };

    inline for (csources) |csrc| {
        lib.addCSourceFile(sokol_path ++ csrc, &[_][]const u8{ "-DIMPL" });
    }
    if (lib.target.isLinux()) {
        lib.linkSystemLibrary("X11");
        lib.linkSystemLibrary("Xi");
        lib.linkSystemLibrary("Xcursor");
        lib.linkSystemLibrary("GL");
        lib.linkSystemLibrary("asound");
    }
    else if (lib.target.isWindows()) {
        lib.linkSystemLibrary("kernel32");
        lib.linkSystemLibrary("user32");
        lib.linkSystemLibrary("gdi32");
        lib.linkSystemLibrary("ole32");
        lib.linkSystemLibrary("d3d11");
        lib.linkSystemLibrary("dxgi");
    }
    return lib;
}

fn buildChip8(b: *bld.Builder, sokol: *bld.LibExeObjStep, comptime name: []const u8) void {
    const e = b.addExecutable(name, "src/main.zig");
    e.linkLibrary(sokol);
    e.setBuildMode(b.standardReleaseOptions());
    e.addPackagePath("sokol", "src/sokol/sokol.zig");
    e.install();
    b.step("run-" ++ name, "Run " ++ name).dependOn(&e.run().step);
}

pub fn build(b: *std.build.Builder) void {
    
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const sokol = buildSokol(b, "");
    const exe = b.addExecutable("chip8-zig", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.linkLibrary(sokol);
    exe.addPackagePath("sokol", "src/sokol/sokol.zig");
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
