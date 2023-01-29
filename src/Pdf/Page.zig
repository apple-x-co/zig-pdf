const Self = @This();
const std = @import("std");
const Size = @import("Size.zig");
const Color = @import("Color.zig");
const Padding = @import("Padding.zig");
const Rect = @import("Rect.zig");
const Border = @import("Border.zig");

frame: Rect,
background_color: Color,
border: ?Border,
bounds: Rect,

pub fn init(content_size: Size, background_color: Color, padding: ?Padding, border: ?Border) Self {
    const width = content_size.width.?;
    const height = content_size.height.?;

    const pad = if (padding == null) Padding.zero() else padding.?;

    return .{
        .frame = Rect.init(0, 0, width, height),
        .background_color = background_color,
        .border = border,
        .bounds = Rect.init(pad.left, pad.top, width - pad.left - pad.right, height - pad.top - pad.bottom),
    };
}
