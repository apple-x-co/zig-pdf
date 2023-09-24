const Self = @This();
const std = @import("std");

pub const zeroSize = init(0, 0);

width: f32,
height: f32,

pub fn init(width: f32, height: f32) Self {
    return .{ .width = width, .height = height };
}
