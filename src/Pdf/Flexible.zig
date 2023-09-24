const Self = @This();
const std = @import("std");
const Random = @import("Random.zig");

child: *anyopaque,
flex: u8,
id: u32,

pub fn init(child: *anyopaque, flex: u8) Self {
    return .{
        .child = child,
        .flex = flex,
        .id = Random.generate(u32),
    };
}
