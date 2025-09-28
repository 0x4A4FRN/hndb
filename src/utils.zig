const std = @import("std");
const mem = std.mem;
const unicode = std.unicode;

pub fn cast(comptime to: type) fn (*anyopaque) *to {
    return (struct {
        pub fn cast(module: *anyopaque) *to {
            return @ptrCast(@alignCast(module));
        }
    }).cast;
}

pub fn toUtf8(gpa: mem.Allocator, bytes: []const u8) ![]u32 {
    const utf8 = try unicode.Utf8View.init(bytes);
    var iter = utf8.iterator();

    var runes = try std.ArrayList(u32).initCapacity(gpa, bytes.len);
    while (iter.nextCodepoint()) |rune| {
        runes.appendAssumeCapacity(rune);
    }

    return runes.toOwnedSlice(gpa);
}
