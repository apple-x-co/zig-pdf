const Self = @This();
const std = @import("std");

top: f32,
right: f32,
bottom: f32,
left: f32,

pub fn init(top: f32, right: f32, bottom: f32, left: f32) Self {
    return .{
        .top = top,
        .right = right,
        .bottom = bottom,
        .left = left,
    };
}

pub fn isZero(self: Self) bool {
    return self.top == null and
        self.right == null and
        self.bottom == null and
        self.left == null;
}
