const std = @import("std");
const fcft = @import("fcft");
const pixman = @import("pixman");

const Config = @This();

bar_height: u16,
bar_width: u16,
bar_margin_top: u16,
bar_margin_left: u16,
bar_margin_bottom: u16,
bar_margin_right: u16,
bar_background_color: pixman.Color,

tag_count: u16,
tag_height: u16,
tag_width: u16,
tag_focused_indicator_color: pixman.Color,
tag_foreground_color_normal: pixman.Color,
tag_foreground_color_focused: pixman.Color,
tag_foreground_color_occupied: pixman.Color,

fonts: *fcft.Font,

fn parseColor(str: []const u8) !pixman.Color {
    var val = try std.fmt.parseUnsigned(u32, str[2..], 16);
    if (str.len == 8) {
        val <<= 8;
        val |= 0xff;
    }

    const bytes: [4]u8 = @bitCast(val);
    return pixman.Color{
        .red = @as(u16, bytes[3]) * 0x101,
        .green = @as(u16, bytes[2]) * 0x101,
        .blue = @as(u16, bytes[1]) * 0x101,
        .alpha = @as(u16, bytes[0]) * 0x101,
    };
}

pub fn init() !Config {
    var font_names = [_][*:0]const u8{"mikachan:size=14"};

    return Config{
        .bar_height = 0,
        .bar_width = 48,
        .bar_margin_top = 4,
        .bar_margin_left = 4,
        .bar_margin_right = 4,
        .bar_margin_bottom = 4,
        .bar_background_color = try parseColor("0x00000000"),
        .tag_count = 9,
        .tag_height = 32,
        .tag_width = 48,
        .tag_focused_indicator_color = try parseColor("0xE6E6E6FF"),
        .tag_foreground_color_normal = try parseColor("0x808080FF"),
        .tag_foreground_color_focused = try parseColor("0xDCDCDCFF"),
        .tag_foreground_color_occupied = try parseColor("0xDCDCDCFF"),
        .fonts = try fcft.Font.fromName(&font_names, null),
    };
}
