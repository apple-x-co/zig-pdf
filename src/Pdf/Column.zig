const Self = @This();
const std = @import("std");
const Alignment = @import("Alignment.zig");
const Random = @import("Random.zig");

alignment: ?Alignment,
children: ?[]*anyopaque, // expect "Container"
id: u32,

pub fn init (alignment: ?Alignment, children: ?[]*anyopaque) Self {
    return .{
        .alignment = alignment,
        .children = children,
        .id = Random.generate(u32),
    };
}