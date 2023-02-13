const Self = @This();
const std = @import("std");
const Random = @import("Random.zig");

content: []const u8,
id: u32,
max_lines: ?u32, // TODO: 
soft_wrap: bool, // TODO: 
text_size: ?f32,

pub fn init(content: []const u8) Self {
    return .{
        .content = content,
        .id = Random.generate(u32),
        .max_lines = null, // TODO: 
        .soft_wrap = false, // TODO: 
        .text_size = null // TODO:
    };
}
