const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        // .link_libc = true,
    });

    const exe = b.addExecutable(.{
        .name = "battray",
        .root_module = root_module,
        .use_llvm = if (optimize == .Debug) true else null,
    });

    exe.linkSystemLibrary("X11");
    exe.linkSystemLibrary("Xrender");
    exe.linkSystemLibrary("Xft");
    exe.linkLibC();

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the tray application");
    run_step.dependOn(&run_cmd.step);
}
