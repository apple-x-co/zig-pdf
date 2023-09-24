const std = @import("std");
const c = @cImport({
    @cInclude("iconv.h");
});

fn encode(allocator: std.mem.Allocator, iconv: c.iconv_t, string: *[]const u8) ![:0]const u8 {
    var input_ptr = string.*;
    var input_length: usize = string.len;

    var output_ptr = try allocator.alloc(u8, string.len * 4);
    for (output_ptr[0..]) |*b| b.* = 0;
    var output = output_ptr;
    var output_length: usize = string.len * 4;

    _ = c.iconv(iconv, @as([*c][*c]u8, @ptrCast(&input_ptr)), &input_length, @as([*c][*c]u8, @ptrCast(&output_ptr)), &output_length);

    var index = std.mem.indexOf(u8, output, "\x00").?;
    var buff = try allocator.dupeZ(u8, output[0..index]);
    allocator.free(output);

    return buff;
}

pub fn encodeSjis(allocator: std.mem.Allocator, utf8: []const u8) ![:0]const u8 {
    const cd = c.iconv_open("SHIFT-JIS", "UTF-8");
    defer _ = c.iconv_close(cd);

    var slice: []const u8 = utf8[0..];

    return encode(allocator, cd, &slice);
}

test "encode" {
    const allocator: std.mem.Allocator = std.testing.allocator;
    const utf8: []const u8 = "こんにちは";
    const sjis = try encodeSjis(allocator, utf8);
    defer allocator.free(sjis);
}
