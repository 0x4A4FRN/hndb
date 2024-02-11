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
bar_foreground_color: pixman.Color,

fonts: *fcft.Font,

pub fn init() !Config {
    var font_names = [_][*:0]const u8{"mikachan:size=14"};

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
            .alpha = 0xE6ff,
        },
        .bar_foreground_color = .{
            .red = 0xffff,
            .green = 0xffff,
            .blue = 0xffff,
            .alpha = 0xffff,
        },
        .fonts = try fcft.Font.fromName(&font_names, null),
    };
}
