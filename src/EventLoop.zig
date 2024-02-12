const std = @import("std");
const log = std.log;
const mem = std.mem;
const os = std.os;

const EventLoop = @This();

const context = &@import("root").context;
const render = @import("render.zig");

sfd: os.fd_t,

pub fn init() !EventLoop {
    var mask = os.empty_sigset;
    os.linux.sigaddset(&mask, os.linux.SIG.INT);
    os.linux.sigaddset(&mask, os.linux.SIG.TERM);
    os.linux.sigaddset(&mask, os.linux.SIG.QUIT);

    _ = os.linux.sigprocmask(os.linux.SIG.BLOCK, &mask, null);
    const sfd = os.linux.signalfd(-1, &mask, os.linux.SFD.NONBLOCK);

    return EventLoop{ .sfd = @intCast(sfd) };
}

pub fn run(self: *EventLoop) !void {
    const wayland = &context.wayland;

    var fds = [_]os.pollfd{
        .{
            .fd = self.sfd,
            .events = os.POLL.IN,
            .revents = undefined,
        },
        .{
            .fd = wayland.fd,
            .events = os.POLL.IN,
            .revents = undefined,
        },
    };

    while (true) {
        while (true) {
            const ret = wayland.display.dispatchPending();
            _ = wayland.display.flush();
            if (ret == .SUCCESS) break;
        }

        _ = os.poll(&fds, -1) catch |err| {
            log.err("poll failed: {s}", .{@errorName(err)});
            return;
        };

        for (fds) |fd| {
            if (fd.revents & os.POLL.HUP != 0 or fd.revents & os.POLL.ERR != 0) {
                return;
            }
        }

        // signals
        if (fds[0].revents & os.POLL.IN != 0) {
            return;
        }

        // wayland
        if (fds[1].revents & os.POLL.IN != 0) {
            const errno = wayland.display.dispatch();
            if (errno != .SUCCESS) return;
        }

        // Use waylands' fd to poll clock
        if (fds[1].revents & os.POLL.IN != 0) {
            for (wayland.monitors.items) |monitor| {
                if (monitor.bar) |bar| {
                    if (!bar.configured) {
                        continue;
                    }

                    try render.renderHour(bar);
                    try render.renderMinute(bar);
                    try render.renderAMPM(bar);

                    bar.clockh.surface.commit();
                    bar.clockm.surface.commit();
                    bar.clockp.surface.commit();

                    bar.background.surface.commit();
                }
            }
        }
        if (fds[1].revents & os.POLL.OUT != 0) {
            const errno = wayland.display.flush();
            if (errno != .SUCCESS) return;
        }
    }
}
