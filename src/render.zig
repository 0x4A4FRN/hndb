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

fn formatDatetime(str: [*:0]const u8) ![]const u8 {
    var buf = try context.gpa.alloc(u8, 256);
    const now = time.time(null);
    const local = time.localtime(&now);
    const len = time.strftime(
        buf.ptr,
        buf.len,
        str,
        local,
    );
    return context.gpa.realloc(buf, len);
}

pub fn renderHour(bar: *Bar) !void {
    const surface = bar.clockh.surface;
    const shm = context.wayland.shm.?;

    // utf8 datetime
    const str = try formatDatetime("%H");
    defer context.gpa.free(str);
    const runes = try utils.toUtf8(context.gpa, str);
    defer context.gpa.free(runes);

    // resterize
    const font = context.config.fonts;
    const run = try font.rasterizeTextRunUtf32(runes, .default);
    defer run.destroy();

    // compute total width
    var i: usize = 0;
    var width: u16 = 0;
    while (i < run.count) : (i += 1) {
        width += @as(u16, @intCast(run.glyphs[i].advance.x));
    }

    // set subsurface offset
    const font_height = @as(u32, @intCast(font.height));
    const x_offset = @as(i32, @intCast((bar.width - width) / 2));
    const y_offset = @as(i32, @intCast((bar.height - font_height * 3) / 2));
    bar.clockh.subsurface.setPosition(x_offset, y_offset);

    const buffers = &bar.clockh.buffers;
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
        const y = context.config.fonts.ascent - @as(i32, @intCast(glyph.y));
        pixman.Image.composite32(.over, color, glyph.pix, buffer.pix.?, 0, 0, 0, 0, x, y, glyph.width, glyph.height);
        x += glyph.advance.x - @as(i32, @intCast(glyph.x));
    }

    surface.setBufferScale(bar.monitor.scale);
    surface.damageBuffer(0, 0, width, bar.height);
    surface.attach(buffer.buffer, 0, 0);
}

pub fn renderMinute(bar: *Bar) !void {
    const surface = bar.clockm.surface;
    const shm = context.wayland.shm.?;

    // utf8 datetime
    const str = try formatDatetime("%M");
    defer context.gpa.free(str);
    const runes = try utils.toUtf8(context.gpa, str);
    defer context.gpa.free(runes);

    // resterize
    const font = context.config.fonts;
    const run = try font.rasterizeTextRunUtf32(runes, .default);
    defer run.destroy();

    // compute total width
    var i: usize = 0;
    var width: u16 = 0;
    while (i < run.count) : (i += 1) {
        width += @as(u16, @intCast(run.glyphs[i].advance.x));
    }

    // set subsurface offset
    const font_height = @as(u32, @intCast(font.height));
    const x_offset = @as(i32, @intCast((bar.width - width) / 2));
    const y_offset = @as(i32, @intCast((bar.height - font_height) / 2));
    bar.clockm.subsurface.setPosition(x_offset, y_offset);

    const buffers = &bar.clockm.buffers;
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
        const y = context.config.fonts.ascent - @as(i32, @intCast(glyph.y));
        pixman.Image.composite32(.over, color, glyph.pix, buffer.pix.?, 0, 0, 0, 0, x, y, glyph.width, glyph.height);
        x += glyph.advance.x - @as(i32, @intCast(glyph.x));
    }

    surface.setBufferScale(bar.monitor.scale);
    surface.damageBuffer(0, 0, width, bar.height);
    surface.attach(buffer.buffer, 0, 0);
}

pub fn renderAMPM(bar: *Bar) !void {
    const surface = bar.clockp.surface;
    const shm = context.wayland.shm.?;

    // utf8 datetime
    const str = try formatDatetime("%p");
    defer context.gpa.free(str);
    const runes = try utils.toUtf8(context.gpa, str);
    defer context.gpa.free(runes);

    // resterize
    const font = context.config.fonts;
    const run = try font.rasterizeTextRunUtf32(runes, .default);
    defer run.destroy();

    // compute total width
    var i: usize = 0;
    var width: u16 = 0;
    while (i < run.count) : (i += 1) {
        width += @as(u16, @intCast(run.glyphs[i].advance.x));
    }

    // set subsurface offset
    const font_height = @as(u32, @intCast(font.height));
    const x_offset = @as(i32, @intCast((bar.width - width) / 2));
    const y_offset = @as(i32, @intCast((bar.height + font_height) / 2));
    bar.clockp.subsurface.setPosition(x_offset, y_offset);

    const buffers = &bar.clockp.buffers;
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
        const y = context.config.fonts.ascent - @as(i32, @intCast(glyph.y));
        pixman.Image.composite32(.over, color, glyph.pix, buffer.pix.?, 0, 0, 0, 0, x, y, glyph.width, glyph.height);
        x += glyph.advance.x - @as(i32, @intCast(glyph.x));
    }

    surface.setBufferScale(bar.monitor.scale);
    surface.damageBuffer(0, 0, width, bar.height);
    surface.attach(buffer.buffer, 0, 0);
}
