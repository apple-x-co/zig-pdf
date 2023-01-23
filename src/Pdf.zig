const Self = @This();
const std = @import("std");

author: ?[]const u8,
creator: ?[]const u8,
title: ?[]const u8,
subject: ?[]const u8,
compression: ?[]const u8,
encryption_mode: ?[]const u8,
encryption_length: ?u32,

pub fn init(author: ?[]const u8, creator: ?[]const u8, title: ?[]const u8, subject: ?[]const u8, compression: ?[]const u8, encryption_mode: ?[]const u8, encryption_length: ?u32) Self {
    return .{
        .author = author,
        .creator = creator,
        .title = title,
        .subject = subject,
        .compression = compression,
        .encryption_mode = encryption_mode,
        .encryption_length = encryption_length,
    };
}

test {
    const pdf = init("apple-x-co", "zig-pdf", "demo", "demo1", "all", "Revision2", null);
    try std.testing.expectEqual(pdf.author, "apple-x-co");
    try std.testing.expectEqual(pdf.creator, "zig-pdf");
    try std.testing.expectEqual(pdf.title, "demo");
    try std.testing.expectEqual(pdf.subject, "demo1");
    try std.testing.expectEqual(pdf.compression, "all");
    try std.testing.expectEqual(pdf.encryption_mode, "Revision2");
    try std.testing.expectEqual(pdf.encryption_length, null);
}
