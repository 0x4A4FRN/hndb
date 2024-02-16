const std = @import("std");
const heap = std.heap;
const io = std.io;
const log = std.log;
const mem = std.mem;
const os = std.os;
const process = std.process;

const fcft = @import("fcft");

const Config = @import("Config.zig");
const Loop = @import("EventLoop.zig");
const Wayland = @import("backend/Wayland.zig");
const Clock = @import("widgets/Clock.zig");
const Battery = @import("widgets/Battery.zig");
const Pulse = @import("widgets/Pulse.zig");

pub const Context = struct {
    gpa: mem.Allocator,
    config: Config,
    wayland: Wayland,
    event_loop: Loop,
    clock: Clock,
    battery: Battery,
    audio: Pulse,
    widget_widths: [4]u16,
};

pub var context: Context = undefined;

pub fn main() anyerror!void {
    var gpa: heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();

    if (@import("builtin").mode == .Debug) {
        _ = fcft.init(.auto, true, .debug);
    } else {
        _ = fcft.init(.auto, false, .err);
    }
    defer fcft.fini();

    context.gpa = gpa.allocator();
    context.config = try Config.init();
    context.wayland = try Wayland.init();
    context.clock = try Clock.init();
    context.battery = try Battery.init();
    context.audio = try Pulse.init();
    try context.audio.start();
    context.event_loop = try Loop.init();
    @memset(&context.widget_widths, 0);

    defer {
        context.wayland.deinit();
        context.battery.deinit();
        context.audio.deinit();
    }

    try context.wayland.registerGlobals();
    try context.event_loop.run();
}
