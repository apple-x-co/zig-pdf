const Self = @This();
const std = @import("std");
const Color = @import("Color.zig");
const Random = @import("Random.zig");

pub const Style = enum { fill, stroke, fill_and_stroke };

char_space: f32,
content: []const u8,
fill_color: Color,
font_family: []const u8,
id: u32,
soft_wrap: bool,
stroke_color: Color,
style: Style,
text_size: f32,
word_space: f32,

pub fn init(content: []const u8, fill_color: Color, stroke_color: ?Color, style: Style, text_size: f32, font_family: []const u8, soft_wrap: bool, char_space: f32, word_space: f32) Self {
    return .{
        .char_space = char_space,
        .content = content,
        .fill_color = fill_color,
        .font_family = font_family,
        .id = Random.generate(u32),
        .soft_wrap = soft_wrap,
        .stroke_color = stroke_color orelse fill_color,
        .style = style,
        .text_size = text_size,
        .word_space = word_space,
    };
}
