const std = @import("std");
const mem = std.mem;
const time = @cImport(@cInclude("time.h"));

const fcft = @import("fcft");
const pixman = @import("pixman");

const Buffer = @import("backend/Buffer.zig");
const Bar = @import("Bar.zig");
const Tag = @import("widgets/Tags.zig").Tag;

const utils = @import("utils.zig");

const context = &@import("root").context;

pub const RenderFn = fn (*Bar) anyerror!void;

pub fn renderTags(bar: *Bar) !void {
    const surface = bar.tags.surface;
    const tags = bar.monitor.tags.tags;

    const buffers = &bar.tags.buffers;
    const shm = context.wayland.shm.?;

    const height = context.config.tag_height * @as(u16, tags.len);
    const buffer = try Buffer.nextBuffer(buffers, shm, bar.width, height);
    if (buffer.buffer == null) return;
    buffer.busy = true;

    for (&tags, 0..) |*tag, i| {
        const offset = context.config.tag_height * i;
        try renderTag(buffer.pix.?, tag, @intCast(offset), bar.width, context.config.tag_height);
    }

    surface.setBufferScale(bar.monitor.scale);
    surface.damageBuffer(0, 0, bar.width, height);
    surface.attach(buffer.buffer, 0, 0);
}

fn renderTag(
    pix: *pixman.Image,
    tag: *const Tag,
    offset: i16,
    width: u16,
    height: u16,
) !void {
    const tag_rect = [_]pixman.Rectangle16{
        .{
            .x = 0,
            .y = offset,
            .width = width,
            .height = height,
        },
    };
    _ = pixman.Image.fillRectangles(.clear, pix, &mem.zeroes(pixman.Color), 1, &tag_rect);

    const glyph_color = tag.glyphColor();

    const tag_focused_indicator = [_]pixman.Rectangle16{
        .{
            .x = 2,
            .y = offset + 4,
            .width = 4,
            .height = height - 8,
        },
    };
    if (tag.focused) {
        _ = pixman.Image.fillRectangles(.over, pix, &context.config.tag_focused_indicator_color, 1, &tag_focused_indicator);
    }

    const font = context.config.fonts;
    var char = pixman.Image.createSolidFill(glyph_color).?;
    defer _ = char.unref();
    const glyph = try font.rasterizeCharUtf32(tag.label, .none);
    const x = @divFloor(width - glyph.width, 2);
    const y = offset + @divFloor(height - glyph.height, 2);
    pixman.Image.composite32(.over, char, glyph.pix, pix, 0, 0, 0, 0, x, y, glyph.width, glyph.height);
}
