const Self = @This();
const std = @import("std");

width: ?f32,
height: ?f32,

pub fn init(width: ?f32, height: ?f32) Self {
    return .{ .width = width, .height = height };
}
