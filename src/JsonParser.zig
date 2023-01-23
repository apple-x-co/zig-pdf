const Self = @This();
const std = @import("std");
const Pdf = @import("Pdf.zig");

file_path: []const u8,

pub fn init(file_path: []const u8) Self {
    return .{
        .file_path = file_path,
    };
}

pub fn parse() Pdf {
    return Pdf.init("apple-x-co", "zig-pdf", "demo", "demo1", "all", "Revision2", null);
}
