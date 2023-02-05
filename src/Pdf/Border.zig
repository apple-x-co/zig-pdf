const Self = @This();
const std = @import("std");
const Color = @import("Color.zig");

pub const Style = enum { dash, solid };

color: Color,
style: Style,
top: f32,
right: f32,
bottom: f32,
left: f32,

pub fn init(color: Color, style: Style, top: f32, right: f32, bottom: f32, left: f32) Self {
    return .{
        .color = color,
        .style = style,
        .top = top,
        .right = right,
        .bottom = bottom,
        .left = left,
    };
}
