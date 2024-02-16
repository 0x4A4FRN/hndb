const std = @import("std");
const mem = std.mem;
const time = @cImport(@cInclude("time.h"));

const fcft = @import("fcft");
const pixman = @import("pixman");

const Buffer = @import("backend/Buffer.zig");
const Bar = @import("Bar.zig");
const Tag = @import("widgets/Tags.zig").Tag;
const Widget = @import("backend/Widget.zig");

const utils = @import("utils.zig");

const context = &@import("root").context;

pub const RenderFn = fn (*Bar) anyerror!void;

pub fn renderTags(bar: *Bar) !void {
    const surface = bar.tags.surface;
    const tags = bar.monitor.tags.tags;

    const buffers = &bar.tags.buffers;
    const shm = context.wayland.shm.?;

    const width = context.config.tag_width * @as(u16, tags.len);
    const buffer = try Buffer.nextBuffer(buffers, shm, width, bar.height);
    if (buffer.buffer == null) return;
    buffer.busy = true;

    for (&tags, 0..) |*tag, i| {
        const offset = context.config.tag_width * i;
        try renderTag(buffer.pix.?, tag, @intCast(offset), context.config.tag_width, bar.height);
    }

    surface.setBufferScale(bar.monitor.scale);
    surface.damageBuffer(0, 0, width, bar.height);
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
            .x = offset,
            .y = 0,
            .width = width,
            .height = height,
        },
    };
    _ = pixman.Image.fillRectangles(.clear, pix, &mem.zeroes(pixman.Color), 1, &tag_rect);

    const glyph_color = tag.glyphColor();

    const tag_focused_indicator = [_]pixman.Rectangle16{
        .{
            .x = offset,
            .y = 0,
            .width = width,
            .height = height,
        },
    };
    if (tag.focused) {
        _ = pixman.Image.fillRectangles(.over, pix, &context.config.tag_focused_indicator_color, 1, &tag_focused_indicator);
    }

    const font = context.config.fonts;
    var char = pixman.Image.createSolidFill(glyph_color).?;
    defer _ = char.unref();
    const glyph = try font.rasterizeCharUtf32(tag.label, .none);
    const x = offset + @divFloor(width - glyph.width, 2);
    const y = @divFloor(height - glyph.height, 2);
    pixman.Image.composite32(.over, char, glyph.pix, pix, 0, 0, 0, 0, x, y, glyph.width, glyph.height);
}

pub fn renderWidget(bar: *Bar, widget: *Widget, str: []const u8, order: usize) !void {
    const surface = widget.surface;
    const shm = context.wayland.shm.?;

    const runes = try utils.toUtf8(context.gpa, str);
    defer context.gpa.free(runes);

    const font = context.config.fonts;

    const run = try font.rasterizeTextRunUtf32(runes, .default);
    defer run.destroy();

    var width: u16 = getRenderWidth(run);
    context.widget_widths[order] = width;

    var i: usize = 0;
    var total_widget_widths: u16 = 0;
    while (i <= order) : (i += 1) {
        total_widget_widths += context.widget_widths[i] + 8;
    }

    const font_height = @as(u32, @intCast(font.height));
    var x_offset = @as(i32, @intCast(bar.width - total_widget_widths));
    var y_offset = @as(i32, @intCast(@divFloor(bar.height - font_height, 2)));
    widget.subsurface.setPosition(x_offset, y_offset);

    const buffers = &widget.buffers;
    const buffer = try Buffer.nextBuffer(buffers, shm, width, bar.height);
    if (buffer.buffer == null) return;
    buffer.busy = true;

    const bg_area = [_]pixman.Rectangle16{
        .{ .x = 0, .y = 0, .width = width, .height = bar.height },
    };
    const bg_color = mem.zeroes(pixman.Color);
    _ = pixman.Image.fillRectangles(.src, buffer.pix.?, &bg_color, 1, &bg_area);

    var x: i32 = 0;
    i = 0;
    var color = pixman.Image.createSolidFill(&context.config.bar_foreground_color).?;
    while (i < run.count) : (i += 1) {
        const glyph = run.glyphs[i];
        x += @as(i32, @intCast(glyph.x));
        const y = font.ascent - @as(i32, @intCast(glyph.y));
        pixman.Image.composite32(.over, color, glyph.pix, buffer.pix.?, 0, 0, 0, 0, x, y, glyph.width, glyph.height);
        x += glyph.advance.x - @as(i32, @intCast(glyph.x));
    }

    surface.setBufferScale(bar.monitor.scale);
    surface.damageBuffer(0, 0, width, bar.height);
    surface.attach(buffer.buffer, 0, 0);
}

fn getRenderWidth(run: *const fcft.TextRun) u16 {
    var i: usize = 0;
    var width: u16 = 0;

    while (i < run.count) : (i += 1) {
        width += @as(u16, @intCast(run.glyphs[i].advance.x));
    }

    return width;
}
