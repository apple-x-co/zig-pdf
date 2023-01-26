const Self = @This();
const std = @import("std");
const Size = @import("Size.zig");

size: Size,

pub fn init(size: Size) Self {
    return .{ .size = size };
}
