const Self = @This();
const std = @import("std");
const Random = @import("Random.zig");
const Size = @import("Size.zig");

bottom: ?f32,
id: u32,
left: ?f32,
right: ?f32,
size: ?Size,
top: ?f32,

pub fn init(top: ?f32, right: ?f32, bottom: ?f32, left: ?f32, size: ?Size) Self {
    return .{
        .bottom = bottom,
        .id = Random.generate(u32),
        .left = left,
        .right = right,
        .size = size,
        .top = top,
    };
}
