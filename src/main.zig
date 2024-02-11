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
};

pub var context: Context = undefined;

pub fn main() anyerror!void {
    var gpa: heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();

    _ = fcft.init(.auto, false, .warning);

    context.gpa = gpa.allocator();
    context.config = try Config.init();
    context.wayland = try Wayland.init();
    context.event_loop = try Loop.init();

    defer {
        context.wayland.deinit();
    }

    try context.wayland.registerGlobals();
    try context.event_loop.run();
}
