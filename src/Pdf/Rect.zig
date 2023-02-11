const Self = @This();
const std = @import("std");
const Point = @import("Point.zig");
const Size = @import("Size.zig");

pub const zeroRect = init(0, 0, 0, 0);

origin: Point,
size: Size,
width: f32,
height: f32,
minX: f32,
midX: f32,
maxX: f32,
minY: f32,
midY: f32,
maxY: f32,

// 原点は左下
pub fn init(x: f32, y: f32, width: f32, height: f32) Self {
    return .{
        .origin = Point.init(x, y),
        .size = Size.init(width, height),
        .width = width,
        .height = height,
        .minX = x,
        .midX = x + (width / 2),
        .maxX = x + width,
        .minY = y,
        .midY = y + (height / 2),
        .maxY = y + height,
    };
}

pub fn offsetBy(self: Self, rect: Self) Self {
    return init(
        self.minX + rect.minX,
        self.minY + rect.minY,
        self.width,
        self.height
    );
}

test {
    const rect = init(10.0, 20.0, 100.0, 200.0);
    try std.testing.expectEqual(@floatCast(f32, 10), rect.minX);
    try std.testing.expectEqual(@floatCast(f32, 60), rect.midX);
    try std.testing.expectEqual(@floatCast(f32, 110), rect.maxX);
    try std.testing.expectEqual(@floatCast(f32, 20), rect.minY);
    try std.testing.expectEqual(@floatCast(f32, 120), rect.midY);
    try std.testing.expectEqual(@floatCast(f32, 220), rect.maxY);
}

test {
    const rect = init(10.0, 20.0, 100.0, 200.0).offsetBy(init(100.0, 200.0, 1000.0, 2000.0));
    try std.testing.expectEqual(@floatCast(f32, 110), rect.minX);
    try std.testing.expectEqual(@floatCast(f32, 160), rect.midX);
    try std.testing.expectEqual(@floatCast(f32, 210), rect.maxX);
    try std.testing.expectEqual(@floatCast(f32, 220), rect.minY);
    try std.testing.expectEqual(@floatCast(f32, 320), rect.midY);
    try std.testing.expectEqual(@floatCast(f32, 420), rect.maxY);
}