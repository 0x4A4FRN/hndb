const std = @import("std");

const EventLoop = @This();

const context = &@import("root").context;
const render = @import("render.zig");

sfd: std.posix.fd_t,

pub fn init() !EventLoop {
    var mask = std.posix.sigemptyset();
    std.posix.sigaddset(&mask, std.posix.SIG.INT);
    std.posix.sigaddset(&mask, std.posix.SIG.TERM);
    std.posix.sigaddset(&mask, std.posix.SIG.QUIT);

    _ = std.posix.sigprocmask(std.posix.SIG.BLOCK, &mask, null);
    const sfd = try std.posix.signalfd(-1, &mask, std.os.linux.SFD.NONBLOCK);

    return EventLoop{ .sfd = @intCast(sfd) };
}

pub fn run(self: *EventLoop) !void {
    const wayland = &context.wayland;
    const clock = &context.clock;
    const audio = &context.audio;

    var fds = [_]std.posix.pollfd{ .{
        .fd = self.sfd,
        .events = std.posix.POLL.IN,
        .revents = undefined,
    }, .{
        .fd = wayland.fd,
        .events = std.posix.POLL.IN,
        .revents = undefined,
    }, .{
        .fd = clock.fd,
        .events = std.posix.POLL.IN,
        .revents = undefined,
    }, .{
        .fd = audio.fd,
        .events = std.posix.POLL.IN,
        .revents = undefined,
    } };

    while (true) {
        while (true) {
            const ret = wayland.display.dispatchPending();
            _ = wayland.display.flush();
            if (ret == .SUCCESS) break;
        }

        _ = std.posix.poll(&fds, -1) catch |err| {
            std.log.err("[HNDB] poll failed: {s}", .{@errorName(err)});
            return;
        };

        for (fds) |fd| {
            if (fd.revents & std.posix.POLL.HUP != 0 or fd.revents & std.posix.POLL.ERR != 0) {
                return;
            }
        }

        // signals
        if (fds[0].revents & std.posix.POLL.IN != 0) {
            return;
        }

        // wayland
        if (fds[1].revents & std.posix.POLL.IN != 0) {
            const errno = wayland.display.dispatch();
            if (errno != .SUCCESS) return;
        }

        if (fds[1].revents & std.posix.POLL.OUT != 0) {
            const errno = wayland.display.flush();
            if (errno != .SUCCESS) return;
        }

        if (fds[2].revents & std.posix.POLL.IN != 0) {
            try clock.refresh();
            try audio.print();
        }

        if (fds[3].revents & std.posix.POLL.IN != 0) {
            try audio.refresh();
        }
    }
}
