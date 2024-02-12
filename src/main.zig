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

pub const Context = struct {
    gpa: mem.Allocator,
    config: Config,
    wayland: Wayland,
    event_loop: Loop,
    clock_width: u16,
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
    context.event_loop = try Loop.init();
    context.clock_width = 0;

    defer {
        context.wayland.deinit();
    }

    try context.wayland.registerGlobals();
    try context.event_loop.run();
}
