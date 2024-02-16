const std = @import("std");
const log = std.log;
const os = std.os;
const time = @cImport(@cInclude("time.h"));

const render = @import("../render.zig");

const Clock = @This();

const context = &@import("root").context;

fd: os.fd_t,

pub fn init() !Clock {
    const tfd = tfd: {
        const fd = os.linux.timerfd_create(os.CLOCK.MONOTONIC, os.linux.TFD.CLOEXEC);
        const interval: os.linux.itimerspec = .{
            .it_interval = .{ .tv_sec = 1, .tv_nsec = 0 },
            .it_value = .{ .tv_sec = 1, .tv_nsec = 0 },
        };

        _ = os.linux.timerfd_settime(@as(i32, @intCast(fd)), 0, &interval, null);
        break :tfd @as(os.fd_t, @intCast(fd));
    };

    return Clock{
        .fd = tfd,
    };
}

pub fn deinit() void {}

pub fn print(self: *Clock) !void {
    _ = self;
    const str = try formatDatetime(context.config.clock_format);
    defer context.gpa.free(str);

    for (context.wayland.monitors.items) |monitor| {
        if (monitor.bar) |bar| {
            if (bar.configured) {
                try render.renderWidget(bar, &bar.clock, str, 0);
                bar.clock.surface.commit();
                bar.background.surface.commit();
            }
        }
    }
}

pub fn refresh(self: *Clock) !void {
    var expirations = std.mem.zeroes([8]u8);
    _ = try os.read(self.fd, &expirations);

    self.print() catch return;
}

fn formatDatetime(format: [*:0]const u8) ![]const u8 {
    var buf = try context.gpa.alloc(u8, 256);
    const now = time.time(null);
    const local = time.localtime(&now);
    const len = time.strftime(
        buf.ptr,
        buf.len,
        format,
        local,
    );
    return context.gpa.realloc(buf, len);
}
