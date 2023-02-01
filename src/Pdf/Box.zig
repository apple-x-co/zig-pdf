const Self = @This();
const std = @import("std");
const Alignment = @import("Alignment.zig");
const Border = @import("Border.zig");
const Color = @import("Color.zig");
const Container = @import("Container.zig");
const Padding = @import("Padding.zig");
const Size = @import("Size.zig");

alignment: ?Alignment,
background_color: ?Color,
border: ?Border,
child: ?Container,
expanded: bool,
padding: ?Padding,
size: ?Size,

pub fn init(expanded: bool, alignment: ?Alignment, background_color: ?Color, border: ?Border, child: ?Container, padding: ?Padding, size: ?Size) Self {
    return .{
        .alignment = alignment,
        .background_color = background_color,
        .border = border,
        .child = child,
        .expanded = expanded,
        .padding = padding,
        .size = size,
    };
}
