const std = @import("std");
const c = @cImport({
    @cInclude("iconv.h");
});

pub fn convertShiftJis(allocator: std.mem.Allocator, utf8: []const u8) ![]u8 {
    const cd = c.iconv_open("SHIFT-JIS", "UTF-8");
    defer _ = c.iconv_close(cd);

    var input = utf8[0..];
    var input_len: usize = input.len;
    var output_len: usize = input_len * 2;
    var output = try allocator.alloc(u8, output_len);
    defer allocator.free(output);

    _ = c.iconv(cd, @ptrCast([*c][*c]u8, &input.ptr), &input_len, @ptrCast([*c][*c]u8, &output.ptr), &output_len);
    var shift_jis = try allocator.dupeZ(u8, output);

    return shift_jis;
}

test {
    const allocator: std.mem.Allocator = std.testing.allocator;
    const utf8: []const u8 = "HELLO";
    const shift_jis = try convertShiftJis(allocator, utf8);
    defer allocator.free(shift_jis);
    std.log.warn("{s} --> {s}", .{ utf8, shift_jis });
}
