const Self = @This();
const std = @import("std");
const Size = @import("Size.zig");
const Color = @import("Color.zig");
const Padding = @import("Padding.zig");
const Rect = @import("Rect.zig");
const Border = @import("Border.zig");

frame: Rect,
bounds: Rect,
backgroundColor: Color,
border: ?Border,

pub fn init(size: Size, backgroundColor: Color, padding: ?Padding, border: ?Border) Self {
    const width = size.width.?;
    const height = size.height.?;

    const pad = if (padding == null) Padding.zero() else padding.?;

    return .{
        .backgroundColor = backgroundColor,
        .frame = Rect.init(0, 0, width, height),
        .bounds = Rect.init(pad.left, pad.top, width - pad.left - pad.right, height - pad.top - pad.bottom),
        .border = border,
    };
}
