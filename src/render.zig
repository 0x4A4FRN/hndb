const std = @import("std");
const mem = std.mem;

const fcft = @import("fcft");
const pixman = @import("pixman");

const Buffer = @import("backend/Buffer.zig");
const Bar = @import("Bar.zig");
const Tag = @import("widgets/Tags.zig").Tag;
const Widget = @import("backend/Widget.zig");

const utils = @import("utils.zig");

const context = &@import("root").context;

pub fn renderTags(bar: *Bar) !void {
    const surface = bar.tags.surface;
    const tags = bar.monitor.tags.tags;

    const buffers = &bar.tags.buffers;
    const shm = context.wayland.shm.?;

    const width = context.config.tag_width * @as(u16, tags.len);
    const buffer = Buffer.nextBuffer(buffers, shm, width, bar.height) catch |err| switch (err) {
        error.NoAvailableBuffers => return,
        else => return err,
    };
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
    pixman.Image.composite32(.over, char, @as(?*pixman.Image, @ptrCast(glyph.pix)), pix, 0, 0, 0, 0, x, y, glyph.width, glyph.height);
}

pub fn renderWidget(bar: *Bar, widget: *Widget, str: []const u8, order: usize) !void {
    const surface = widget.surface;
    const shm = context.wayland.shm.?;

    const runes = try utils.toUtf8(context.gpa, str);
    defer context.gpa.free(runes);

    const font = context.config.fonts;

    const run = try font.rasterizeTextRunUtf32(runes, .default);
    defer run.destroy();

    const width: u16 = std.math.cast(u16, getRenderWidth(run)) orelse std.math.maxInt(u16);
    context.widget_widths[order] = width;

    var i: usize = 0;
    var total_widget_widths: u16 = 0;
    while (i <= order) : (i += 1) {
        total_widget_widths += context.widget_widths[i] + 8;
    }

    const font_height = @as(u32, @intCast(font.height));
    const x_offset = @as(i32, @intCast(bar.width - total_widget_widths));
    const y_offset = @as(i32, @intCast(@divFloor(bar.height - font_height, 2)));
    widget.subsurface.setPosition(x_offset, y_offset);

    const buffers = &widget.buffers;
    const buffer = Buffer.nextBuffer(buffers, shm, width, bar.height) catch |err| switch (err) {
        error.NoAvailableBuffers => return,
        else => return err,
    };
    if (buffer.buffer == null) return;
    buffer.busy = true;

    const bg_area = [_]pixman.Rectangle16{
        .{ .x = 0, .y = 0, .width = width, .height = bar.height },
    };
    const bg_color = mem.zeroes(pixman.Color);
    _ = pixman.Image.fillRectangles(.src, buffer.pix.?, &bg_color, 1, &bg_area);

    var x: i32 = 0;
    i = 0;
    const color = pixman.Image.createSolidFill(&context.config.bar_foreground_color).?;
    defer _ = color.unref();
    while (i < run.count) : (i += 1) {
        const glyph = run.glyphs[i];
        x += @as(i32, @intCast(glyph.x));
        const y = font.ascent - @as(i32, @intCast(glyph.y));
        pixman.Image.composite32(.over, color, @as(?*pixman.Image, @ptrCast(glyph.pix)), buffer.pix.?, 0, 0, 0, 0, x, y, glyph.width, glyph.height);
        x += glyph.advance.x - @as(i32, @intCast(glyph.x));
    }

    surface.setBufferScale(bar.monitor.scale);
    surface.damageBuffer(0, 0, width, bar.height);
    surface.attach(buffer.buffer, 0, 0);
}

fn getRenderWidth(run: *const fcft.TextRun) u32 {
    var i: usize = 0;
    var width: u32 = 0;

    while (i < run.count) : (i += 1) {
        width += @as(u32, @intCast(run.glyphs[i].advance.x));
    }

    return width;
}

pub fn renderCenterTitle(bar: *Bar) !void {
    const title_z = context.wayland.focused_view_title orelse return;
    const title: []const u8 = title_z;

    const surface = bar.title.surface;
    const shm = context.wayland.shm.?;

    const font = context.config.fonts;
    const font_height: u32 = @intCast(font.height);
    var width: u32 = 0;

    if (title.len != 0) {
        const runes = try utils.toUtf8(context.gpa, title);
        defer context.gpa.free(runes);

        const run = try font.rasterizeTextRunUtf32(runes, .default);
        defer run.destroy();
        width = getRenderWidth(run);

        if (width == 0) width = 1;

        const max_w: u32 = if (bar.width > 8) @as(u32, @intCast(bar.width - 8)) else 1;
        if (width > max_w) width = max_w;

        const x_offset: i32 = @divFloor(@as(i32, @intCast(@as(i32, @intCast(bar.width)) - @as(i32, @intCast(width)))), 2);
        const y_offset: i32 = @intCast(@divFloor(@as(i32, @intCast(bar.height)) - @as(i32, @intCast(font_height)), 2));
        bar.title.subsurface.setPosition(x_offset, y_offset);

        const buffers = &bar.title.buffers;
        const width_u16: u16 = @intCast(width);
        const buffer = Buffer.nextBuffer(buffers, shm, width_u16, bar.height) catch |err| switch (err) {
            error.NoAvailableBuffers => return,
            else => return err,
        };
        if (buffer.buffer == null) return;
        buffer.busy = true;

        const pix = buffer.pix.?;
        const bg_area = [_]pixman.Rectangle16{
            .{ .x = 0, .y = 0, .width = width_u16, .height = bar.height },
        };
        const bg_color = mem.zeroes(pixman.Color);
        _ = pixman.Image.fillRectangles(.src, pix, &bg_color, 1, &bg_area);

        if (run.count > 0) {
            var x: i32 = 0;
            const color = pixman.Image.createSolidFill(&context.config.bar_foreground_color).?;
            defer _ = color.unref();
            var i: usize = 0;
            while (i < run.count) : (i += 1) {
                const glyph = run.glyphs[i];
                x += @as(i32, @intCast(glyph.x));
                const y = font.ascent - @as(i32, @intCast(glyph.y));
                pixman.Image.composite32(.over, color, @as(?*pixman.Image, @ptrCast(glyph.pix)), pix, 0, 0, 0, 0, x, y, glyph.width, glyph.height);
                x += glyph.advance.x - @as(i32, @intCast(glyph.x));
            }
        }

        surface.setBufferScale(bar.monitor.scale);
        surface.damageBuffer(0, 0, width_u16, bar.height);
        surface.attach(buffer.buffer, 0, 0);
        return;
    }

    bar.title.subsurface.setPosition(0, 0);
    surface.setBufferScale(bar.monitor.scale);
    surface.damageBuffer(0, 0, bar.width, bar.height);
    surface.attach(null, 0, 0);
}
