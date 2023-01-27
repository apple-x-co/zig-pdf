const Self = @This();
const std = @import("std");
const Size = @import("Size.zig");
const Color = @import("Color.zig");

size: Size,
color: Color,

pub fn init(size: Size, color: Color) Self {
    return .{ .size = size, .color = color };
}
