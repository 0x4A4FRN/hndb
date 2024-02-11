const std = @import("std");

const Scanner = @import("deps/zig-wayland/build.zig").Scanner;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const scanner = Scanner.create(b, .{});

    scanner.addSystemProtocol("stable/xdg-shell/xdg-shell.xml");
    scanner.addSystemProtocol("stable/viewporter/viewporter.xml");
    scanner.addSystemProtocol("staging/single-pixel-buffer/single-pixel-buffer-v1.xml");
    scanner.addCustomProtocol("protocol/wlr-layer-shell-unstable-v1.xml");
    scanner.addCustomProtocol("protocol/river-status-unstable-v1.xml");
    scanner.addCustomProtocol("protocol/river-control-unstable-v1.xml");

    scanner.generate("wl_compositor", 4);
    scanner.generate("wl_subcompositor", 1);
    scanner.generate("wl_shm", 1);
    scanner.generate("wl_output", 3);
    scanner.generate("wl_seat", 5);
    scanner.generate("wp_single_pixel_buffer_manager_v1", 1);
    scanner.generate("wp_viewporter", 1);
    scanner.generate("zwlr_layer_shell_v1", 1);
    scanner.generate("zriver_status_manager_v1", 1);
    scanner.generate("zriver_control_v1", 1);

    const wayland = b.createModule(.{ .source_file = scanner.result });

    const pixman = b.createModule(.{
        .source_file = .{ .path = "deps/zig-pixman/pixman.zig" },
    });

    const fcft = b.createModule(.{
        .source_file = .{ .path = "deps/zig-fcft/fcft.zig" },
        .dependencies = &.{
            .{ .name = "pixman", .module = pixman },
        },
    });

    const exe = b.addExecutable(.{
        .name = "hndb",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addModule("fcft", fcft);
    exe.addModule("pixman", pixman);
    exe.addModule("wayland", wayland);

    exe.linkLibC();
    exe.linkSystemLibrary("fcft");
    exe.linkSystemLibrary("pixman-1");
    exe.linkSystemLibrary("wayland-client");

    scanner.addCSource(exe);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
