const Self = @This();
const std = @import("std");
const Random = @import("Random.zig");
const Size = @import("Size.zig");

id: u32,
path: []const u8,
size: ?Size,

pub fn init(path: []const u8, size: ?Size) Self {
    return .{
        .id = Random.generate(u32),
        .path = path,
        .size = size,
    };
}
