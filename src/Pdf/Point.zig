const Self = @This();
const std = @import("std");

x: f32,
y: f32,

pub fn init(x: f32, y: f32) Self {
    return .{
        .x = x,
        .y = y,
    };
}
