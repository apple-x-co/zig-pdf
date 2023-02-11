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

pub fn insets(self: Self, top: ?f32, right: ?f32, bottom: ?f32, left :?f32) Self {
    return init(
        self.minX + (left orelse 0),
        self.minY + (bottom orelse 0),
        self.width - (left orelse 0) - (right orelse 0),
        self.height - (top orelse 0) - (right orelse 0)
    );
}

pub fn offsetLTWH(self: Self, left: f32, top: f32, width: f32, height: f32) Self {
    return init(
        self.minX + left,
        self.maxY - top - height,
        width,
        height
    );
}

pub fn offsetCenterXYWH(self: Self, x: f32, y: f32, width: f32, height: f32) Self {
    return init(
        self.midX + x,
        self.midY + y,
        width,
        height
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
    const rect = init(10.0, 20.0, 100.0, 200.0).insets(5, 5, 5, 5);
    try std.testing.expectEqual(@floatCast(f32, 15), rect.minX);
    try std.testing.expectEqual(@floatCast(f32, 60), rect.midX);
    try std.testing.expectEqual(@floatCast(f32, 105), rect.maxX);
    try std.testing.expectEqual(@floatCast(f32, 25), rect.minY);
    try std.testing.expectEqual(@floatCast(f32, 120), rect.midY);
    try std.testing.expectEqual(@floatCast(f32, 215), rect.maxY);
}

test {
    const rect = init(0, 0, 100.0, 200.0).offsetLTWH(5, 5, 50, 100);
    try std.testing.expectEqual(@floatCast(f32, 5), rect.minX);
    try std.testing.expectEqual(@floatCast(f32, 30), rect.midX);
    try std.testing.expectEqual(@floatCast(f32, 55), rect.maxX);
    try std.testing.expectEqual(@floatCast(f32, 95), rect.minY);
    try std.testing.expectEqual(@floatCast(f32, 145), rect.midY);
    try std.testing.expectEqual(@floatCast(f32, 195), rect.maxY);
}

test {
    const rect = init(0, 0, 100.0, 200.0).offsetCenterXYWH(-5, -5, 50, 100);
    try std.testing.expectEqual(@floatCast(f32, 45), rect.minX);
    try std.testing.expectEqual(@floatCast(f32, 70), rect.midX);
    try std.testing.expectEqual(@floatCast(f32, 95), rect.maxX);
    try std.testing.expectEqual(@floatCast(f32, 95), rect.minY);
    try std.testing.expectEqual(@floatCast(f32, 145), rect.midY);
    try std.testing.expectEqual(@floatCast(f32, 195), rect.maxY);
}