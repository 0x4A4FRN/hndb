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
bar_foreground_color_normal: pixman.Color,
bar_foreground_color_focused: pixman.Color,

tag_count: u16,
tag_height: u16,

fonts: *fcft.Font,

pub fn init() !Config {
    var font_names = [_][*:0]const u8{"mikachan:size=16"};

    return Config{
        .bar_height = 0,
        .bar_width = 48,
        .bar_margin_top = 4,
        .bar_margin_left = 4,
        .bar_margin_right = 4,
        .bar_margin_bottom = 4,
        .bar_background_color = .{
            .red = 0x11ff,
            .green = 0x11ff,
            .blue = 0x11ff,
            .alpha = 0xe6ff,
        },
        .bar_foreground_color_focused = .{
            .red = 0xffff,
            .green = 0xffff,
            .blue = 0xffff,
            .alpha = 0xffff,
        },
        .bar_foreground_color_normal = .{
            .red = 0x80ff,
            .green = 0x80ff,
            .blue = 0x80ff,
            .alpha = 0xffff,
        },
        .tag_count = 6,
        .tag_height = 40,
        .fonts = try fcft.Font.fromName(&font_names, null),
    };
}
