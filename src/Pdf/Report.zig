const Self = @This();
const std = @import("std");
const Random = @import("Random.zig");

body: *anyopaque,
footer: ?*anyopaque,
fixedFooter: bool,
fixedHeader: bool,
header: ?*anyopaque,
id: u32,

pub fn init(header: ?*anyopaque, fixedHeader: bool, body: *anyopaque, footer: ?*anyopaque, fixedFooter: bool) Self {
    return .{
        .body = body,
        .footer = footer,
        .fixedFooter = fixedFooter,
        .fixedHeader = fixedHeader,
        .header = header,
        .id = Random.generate(u32),
    };
}
