const Self = @This();
const std = @import("std");
const Size = @import("Size.zig");
const Color = @import("Color.zig");
const Padding = @import("Padding.zig");
const Rect = @import("Rect.zig");

frame: Rect,
bounds: Rect,
backgroundColor: Color,

pub fn init(size: Size, backgroundColor: Color, padding: Padding) Self {
    const width = size.width.?;
    const height = size.height.?;

    return .{
        .frame = Rect.init(0, 0, width, height),
        .bounds = Rect.init(padding.left, padding.top, width - padding.left - padding.right, height - padding.top - padding.bottom),
        .backgroundColor = backgroundColor,
    };
}
