const Self = @This();
const std = @import("std");
const Alignment = @import("Alignment.zig");
const Border = @import("Border.zig");
const Container = @import("Container.zig");
const Color = @import("Color.zig");
const Padding = @import("Padding.zig");
const Rect = @import("Rect.zig");
const Size = @import("Size.zig");

alignment: ?Alignment,
background_color: ?Color,
border: ?Border,
bounds: Rect,
container: Container.Box,
frame: Rect,

pub fn init(container: Container.Box, page_size: Size, background_color: ?Color, padding: ?Padding, alignment: ?Alignment, border: ?Border) Self {
    const width: f32 = page_size.width;
    const height: f32 = page_size.height;

    const pad = if (padding == null) Padding.zero() else padding.?;

    return .{
        .alignment = alignment,
        .background_color = background_color,
        .border = border,
        .bounds = Rect.init(pad.left, pad.top, width - pad.left - pad.right, height - pad.top - pad.bottom),
        .container = container,
        .frame = Rect.init(0, 0, width, height),
    };
}
