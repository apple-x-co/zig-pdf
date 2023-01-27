const Self = @This();
const std = @import("std");

value: ?[]const u8,

pub fn init(value: ?[]const u8) Self {
    return .{ .value = value };
}
