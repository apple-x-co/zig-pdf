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

// @var x1 left-top x
// @var y1 left-top y
// @var x2 right-bottom x
// @var y2 right-bottom y
pub fn fromPoints(x1: f32, y1: f32, x2: f32, y2: f32) Self {
    const x: f32 = x1;
    const y: f32 = y2;
    const width: f32 = x2 - x1;
    const height: f32 = y1 - y2;

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

pub fn insets(self: Self, top: ?f32, right: ?f32, bottom: ?f32, left: ?f32) Self {
    return init(self.minX + (left orelse 0), self.minY + (bottom orelse 0), self.width - (left orelse 0) - (right orelse 0), self.height - (top orelse 0) - (bottom orelse 0));
}

pub fn offsetLTWH(self: Self, left: f32, top: f32, width: f32, height: f32) Self {
    return init(self.minX + left, self.maxY - top - height, width, height);
}

pub fn offsetCenterXYWH(self: Self, x: f32, y: f32, width: f32, height: f32) Self {
    return init(self.midX + x, self.midY + y, width, height);
}

test "rect1" {
    const rect = init(10.0, 20.0, 100.0, 200.0);
    try std.testing.expectEqual(@as(f32, @floatCast(10)), rect.minX);
    try std.testing.expectEqual(@as(f32, @floatCast(60)), rect.midX);
    try std.testing.expectEqual(@as(f32, @floatCast(110)), rect.maxX);
    try std.testing.expectEqual(@as(f32, @floatCast(20)), rect.minY);
    try std.testing.expectEqual(@as(f32, @floatCast(120)), rect.midY);
    try std.testing.expectEqual(@as(f32, @floatCast(220)), rect.maxY);
}

test "recct2" {
    const rect = init(10.0, 20.0, 100.0, 200.0).insets(5, 5, 5, 5);
    try std.testing.expectEqual(@as(f32, @floatCast(15)), rect.minX);
    try std.testing.expectEqual(@as(f32, @floatCast(60)), rect.midX);
    try std.testing.expectEqual(@as(f32, @floatCast(105)), rect.maxX);
    try std.testing.expectEqual(@as(f32, @floatCast(25)), rect.minY);
    try std.testing.expectEqual(@as(f32, @floatCast(120)), rect.midY);
    try std.testing.expectEqual(@as(f32, @floatCast(215)), rect.maxY);
}

test "rect3" {
    const rect = init(0, 0, 100.0, 200.0).offsetLTWH(5, 5, 50, 100);
    try std.testing.expectEqual(@as(f32, @floatCast(5)), rect.minX);
    try std.testing.expectEqual(@as(f32, @floatCast(30)), rect.midX);
    try std.testing.expectEqual(@as(f32, @floatCast(55)), rect.maxX);
    try std.testing.expectEqual(@as(f32, @floatCast(95)), rect.minY);
    try std.testing.expectEqual(@as(f32, @floatCast(145)), rect.midY);
    try std.testing.expectEqual(@as(f32, @floatCast(195)), rect.maxY);
}

test "rect4" {
    const rect = init(0, 0, 100.0, 200.0).offsetCenterXYWH(-5, -5, 50, 100);
    try std.testing.expectEqual(@as(f32, @floatCast(45)), rect.minX);
    try std.testing.expectEqual(@as(f32, @floatCast(70)), rect.midX);
    try std.testing.expectEqual(@as(f32, @floatCast(95)), rect.maxX);
    try std.testing.expectEqual(@as(f32, @floatCast(95)), rect.minY);
    try std.testing.expectEqual(@as(f32, @floatCast(145)), rect.midY);
    try std.testing.expectEqual(@as(f32, @floatCast(195)), rect.maxY);
}

test "rect5" {
    const rect = fromPoints(1, 6, 6, 3);
    try std.testing.expectEqual(@as(f32, @floatCast(1)), rect.minX);
    try std.testing.expectEqual(@as(f32, @floatCast(3.5)), rect.midX);
    try std.testing.expectEqual(@as(f32, @floatCast(6)), rect.maxX);
    try std.testing.expectEqual(@as(f32, @floatCast(3)), rect.minY);
    try std.testing.expectEqual(@as(f32, @floatCast(4.5)), rect.midY);
    try std.testing.expectEqual(@as(f32, @floatCast(6)), rect.maxY);
}
