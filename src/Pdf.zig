const Self = @This();
const std = @import("std");
const CompressionMode = @import("compression.zig").Mode;
const EncryptionMode = @import("encryption.zig").Mode;
const PermissionName = @import("permission.zig").Name;

author: ?[]const u8,
creator: ?[]const u8,
title: ?[]const u8,
subject: ?[]const u8,
compression_mode: ?CompressionMode,
owner_password: ?[]const u8,
user_password: ?[]const u8,
encryption_mode: ?EncryptionMode,
encryption_length: ?u32,
permission_names: ?[]const PermissionName,

pub fn init(author: ?[]const u8, creator: ?[]const u8, title: ?[]const u8, subject: ?[]const u8, compression_mode: ?CompressionMode, owner_password: ?[]const u8, user_password: ?[]const u8, encryption_mode: ?EncryptionMode, encryption_length: ?u32, permission_names: ?[]const PermissionName) Self {
    return .{
        .author = author,
        .creator = creator,
        .title = title,
        .subject = subject,
        .compression_mode = compression_mode,
        .owner_password = owner_password,
        .user_password = user_password,
        .encryption_mode = encryption_mode,
        .encryption_length = encryption_length,
        .permission_names = permission_names,
    };
}

test {
    const permissions = [_]PermissionName{
        PermissionName.copy,
        PermissionName.print,
    };

    const pdf = init("apple-x-co", "zig-pdf", "demo", "demo1", CompressionMode.all, null, null, EncryptionMode.Revision2, null, &permissions);
    try std.testing.expectEqual(pdf.author, "apple-x-co");
    try std.testing.expectEqual(pdf.creator, "zig-pdf");
    try std.testing.expectEqual(pdf.title, "demo");
    try std.testing.expectEqual(pdf.subject, "demo1");
    try std.testing.expectEqual(pdf.compression_mode, CompressionMode.all);
    try std.testing.expectEqual(pdf.owner_password, null);
    try std.testing.expectEqual(pdf.user_password, null);
    try std.testing.expectEqual(pdf.encryption_mode, EncryptionMode.Revision2);
    try std.testing.expectEqual(pdf.encryption_length, null);
    try std.testing.expectEqual(pdf.permission_names.?[0], PermissionName.copy);
    try std.testing.expectEqual(pdf.permission_names.?[1], PermissionName.print);
}
