const std = @import("std");
const log = std.log;

const zriver = @import("wayland").client.zriver;
const pixman = @import("pixman");

const Monitor = @import("../backend/Monitor.zig");
const Bar = @import("../Bar.zig");
const Buffer = @import("../backend/Buffer.zig");
const Tags = @This();

const context = &@import("root").context;
const config = &context.config;
const render = @import("../render.zig");

monitor: *Monitor,
output_status: *zriver.OutputStatusV1,
tags: [9]Tag,

pub const Tag = struct {
    label: u32,
    focused: bool = false,
    occupied: bool = false,

    pub fn glyphColor(self: *const Tag) *pixman.Color {
        if (self.focused) {
            return &config.tag_foreground_color_focused;
        } else if (self.occupied) {
            return &config.tag_foreground_color_occupied;
        } else {
            return &config.tag_foreground_color_normal;
        }
    }
};

pub fn create(monitor: *Monitor) !*Tags {
    const self = try context.gpa.create(Tags);
    const manager = context.wayland.status_manager.?;

    self.monitor = monitor;
    self.output_status = try manager.getRiverOutputStatus(monitor.output);

    const labels = [_]u32{ 0x4E00, 0x4E8C, 0x4E09, 0x56DB, 0x4E94, 0x516D, 0x4E03, 0x516B, 0x4E5D };

    for (&self.tags, 0..) |*tag, i| {
        tag.label = labels[i];
    }

    self.output_status.setListener(*Tags, outputStatusListener, self);
    return self;
}

pub fn destroy(self: *Tags) void {
    self.output_status.destroy();
    context.gpa.destroy(self);
}

fn outputStatusListener(
    _: *zriver.OutputStatusV1,
    event: zriver.OutputStatusV1.Event,
    tags: *Tags,
) void {
    switch (event) {
        .focused_tags => |data| {
            for (&tags.tags, 0..) |*tag, i| {
                const mask = @as(u32, 1) << @as(u5, @intCast(i));
                tag.focused = data.tags & mask != 0;
            }
        },
        .view_tags => |data| {
            for (&tags.tags) |*tag| {
                tag.occupied = false;
            }
            for (data.tags.slice(u32)) |view| {
                for (&tags.tags, 0..) |*tag, i| {
                    const mask = @as(u32, 1) << @as(u5, @intCast(i));
                    if (view & mask != 0) tag.occupied = true;
                }
            }
        },
    }
    if (tags.monitor.bar) |bar| {
        if (bar.configured) {
            render.renderTags(bar) catch |err| {
                std.log.err("Failed to render Tags for monitor {}: {s}", .{ bar.monitor.globalName, @errorName(err) });
                return;
            };

            bar.tags.surface.commit();
            bar.background.surface.commit();
        }
    }
}
