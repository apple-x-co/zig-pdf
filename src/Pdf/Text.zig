const Self = @This();
const std = @import("std");
const Color = @import("Color.zig");
const Font = @import("Font.zig");
const Random = @import("Random.zig");

color: ?Color,
content: []const u8,
font: ?Font.Font,
id: u32,
max_lines: ?u32, // TODO:
soft_wrap: bool, // TODO:
text_size: ?f32,

pub fn init(content: []const u8, color: ?Color, text_size: ?f32, font: ?Font.Font) Self {
    return .{
        .color = color,
        .content = content,
        .font = font,
        .id = Random.generate(u32),
        .max_lines = null, // TODO:
        .soft_wrap = false, // TODO:
        .text_size = text_size,
    };
}
