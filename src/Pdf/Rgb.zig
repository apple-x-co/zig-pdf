const Self = @This();
const std = @import("std");
const Color = @import("Color.zig");

red: u8,
green: u8,
blue: u8,
alpha: u8,

pub fn init(red: u8, green: u8, blue: u8, alphar: u8) Self {
    return .{
        .red = red,
        .green = green,
        .blue = blue,
        .alpha = alphar,
    };
}

pub fn hex(value: []const u8) !Self {
    switch (value.len) {
        3 => {
            const r = try std.fmt.parseInt(u8, value[0..1], 16);
            const g = try std.fmt.parseInt(u8, value[1..2], 16);
            const b = try std.fmt.parseInt(u8, value[2..3], 16);
            return init(
                r | (r << 4),
                g | (g << 4),
                b | (b << 4),
                1,
            );
        },
        6 => {
            const r = try std.fmt.parseInt(u8, value[0..2], 16);
            const g = try std.fmt.parseInt(u8, value[2..4], 16);
            const b = try std.fmt.parseInt(u8, value[4..6], 16);
            return init(
                r,
                g,
                b,
                1,
            );
        },
        8 => {
            const r = try std.fmt.parseInt(u8, value[0..2], 16);
            const g = try std.fmt.parseInt(u8, value[2..4], 16);
            const b = try std.fmt.parseInt(u8, value[4..6], 16);
            const a = try std.fmt.parseInt(u8, value[6..8], 16);
            return init(
                r,
                g,
                b,
                a,
            );
        },
        else => return init(0, 0, 0, 1),
    }
}
