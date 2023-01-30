const Self = @This();
const std = @import("std");
const Alignment = @import("Alignment.zig");
const Border = @import("Border.zig");
const Color = @import("Color.zig");
const Padding = @import("Padding.zig");
const Size = @import("Size.zig");

alignment: ?Alignment,
border: ?Border,
// child: Xxx,
color: ?Color,
expanded: bool,
padding: ?Padding,
size: ?Size,

pub fn init(expanded: bool, alignment: ?Alignment, border: ?Border, color: ?Color, padding: ?Padding, size: ?Size) Self {
    return .{
        .alignment = alignment,
        .border = border,
        .color = color,
        .expanded = expanded,
        .padding = padding,
        .size = size,
    };
}
