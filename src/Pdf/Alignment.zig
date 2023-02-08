const Self = @This();
const std = @import("std");

pub const topLeft = init(-1, -1);
pub const topCenter = init(0, -1);
pub const topRight = init(1, -1);
pub const centerLeft = init(-1, 0);
pub const center = init(0, 0);
pub const centerRight = init(1, 0);
pub const bottomLeft = init(-1, 1);
pub const bottomCenter = init(0, 1);
pub const bottomRight = init(1, 1);

x: f32,
y: f32,

pub fn init(x: f32, y: f32) Self {
    return .{
        .x = x,
        .y = y,
    };
}
