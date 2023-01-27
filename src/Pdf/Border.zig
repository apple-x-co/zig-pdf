const Self = @This();
const std = @import("std");
const Color = @import("Color.zig");

color: Color,
top: f32,
right: f32,
bottom: f32,
left: f32,

pub fn init(color: Color, top: f32, right: f32, bottom: f32, left: f32) Self {
    return .{
        .color = color,
        .top = top,
        .right = right,
        .bottom = bottom,
        .left = left,
    };
}
