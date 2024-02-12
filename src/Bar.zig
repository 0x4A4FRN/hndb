const std = @import("std");
const mem = std.mem;

const wl = @import("wayland").client.wl;
const wp = @import("wayland").client.wp;
const zwlr = @import("wayland").client.zwlr;

const Buffer = @import("backend/Buffer.zig");
const Monitor = @import("backend/Monitor.zig");
const Widget = @import("backend/Widget.zig");

const Bar = @This();

const context = &@import("root").context;
const config = &context.config;

const render = @import("render.zig");

monitor: *Monitor,

layer_surface: *zwlr.LayerSurfaceV1,
background: struct {
    surface: *wl.Surface,
    viewport: *wp.Viewport,
    buffer: *wl.Buffer,
},

tags: Widget,
clock: Widget,

configured: bool,
width: u16,
height: u16,

fn toRgba(color: u16) u32 {
    return (@as(u32, color) >> 8) << 24 | 0xffffff;
}

pub fn create(monitor: *Monitor) !*Bar {
    const self = try context.gpa.create(Bar);
    const bar_bg_color = &config.bar_background_color;

    self.monitor = monitor;
    self.configured = false;

    const compositor = context.wayland.compositor.?;
    const viewporter = context.wayland.viewporter.?;
    const spb_manager = context.wayland.single_pixel_buffer_manager.?;
    const layer_shell = context.wayland.layer_shell.?;

    self.background.surface = try compositor.createSurface();
    self.background.viewport = try viewporter.getViewport(self.background.surface);
    self.background.buffer = try spb_manager.createU32RgbaBuffer(
        toRgba(bar_bg_color.red),
        toRgba(bar_bg_color.green),
        toRgba(bar_bg_color.blue),
        toRgba(bar_bg_color.alpha),
    );

    self.layer_surface = try layer_shell.getLayerSurface(self.background.surface, monitor.output, .top, "hndb");

    self.layer_surface.setSize(config.bar_width, config.bar_height);
    self.layer_surface.setAnchor(.{ .top = false, .left = true, .bottom = true, .right = true });
    self.layer_surface.setExclusiveZone(config.bar_height);
    self.layer_surface.setMargin(config.bar_margin_top, config.bar_margin_left, config.bar_margin_bottom, config.bar_margin_right);
    self.layer_surface.setListener(*Bar, layerSurfaceListener, self);

    self.tags = try Widget.init(self.background.surface);
    self.clock = try Widget.init(self.background.surface);

    self.tags.surface.commit();
    self.clock.surface.commit();
    self.background.surface.commit();

    return self;
}

pub fn destroy(self: *Bar) void {
    self.monitor.bar = null;
    self.layer_surface.destroy();

    self.background.surface.destroy();
    self.background.viewport.destroy();
    self.background.buffer.destroy();

    self.tags.deinit();
    self.clock.deinit();

    context.gpa.destroy(self);
}

fn layerSurfaceListener(
    layerSurface: *zwlr.LayerSurfaceV1,
    event: zwlr.LayerSurfaceV1.Event,
    bar: *Bar,
) void {
    switch (event) {
        .configure => |data| {
            bar.configured = true;
            bar.width = @intCast(data.width);
            bar.height = @intCast(data.height);

            layerSurface.ackConfigure(data.serial);

            const bg = &bar.background;
            bg.surface.attach(bg.buffer, 0, 0);
            bg.surface.damageBuffer(0, 0, bar.width, bar.height);
            bg.viewport.setDestination(bar.width, bar.height);

            render.renderTags(bar) catch |err| {
                std.log.err("Failed to render Tags for monitor {}: {s}", .{ bar.monitor.globalName, @errorName(err) });
                return;
            };

            bar.tags.surface.commit();
            bar.clock.surface.commit();
            bar.background.surface.commit();
        },
        .closed => bar.destroy(),
    }
}
