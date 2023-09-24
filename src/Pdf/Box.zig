const Self = @This();
const std = @import("std");
const Alignment = @import("Alignment.zig");
const Border = @import("Border.zig");
const Color = @import("Color.zig");
const Padding = @import("Padding.zig");
const Random = @import("Random.zig");
const Size = @import("Size.zig");

alignment: ?Alignment,
background_color: ?Color,
border: ?Border,
child: ?*anyopaque,
expanded: bool,
id: u32,
padding: ?Padding,
size: ?Size,

pub fn init(expanded: bool, alignment: ?Alignment, background_color: ?Color, border: ?Border, child: ?*anyopaque, padding: ?Padding, size: ?Size) Self {
    return .{
        .alignment = alignment,
        .background_color = background_color,
        .border = border,
        .child = child,
        .expanded = expanded,
        .id = Random.generate(u32),
        .padding = padding,
        .size = size,
    };
}
