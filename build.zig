const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const c_headers = b.addTranslateC(.{
        .root_source_file = b.path("src/x11.h"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    c_headers.linkSystemLibrary("X11", .{});
    c_headers.linkSystemLibrary("cairo", .{});

    const root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    root_module.addImport("c", c_headers.createModule());

    const exe = b.addExecutable(.{
        .name = "battray",
        .root_module = root_module,
    });

    root_module.linkSystemLibrary("X11", .{});
    root_module.linkSystemLibrary("cairo", .{});

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the tray application");
    run_step.dependOn(&run_cmd.step);
}
