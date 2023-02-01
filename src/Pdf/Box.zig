const Self = @This();
const std = @import("std");
const Alignment = @import("Alignment.zig");
const Border = @import("Border.zig");
const Color = @import("Color.zig");
const Container = @import("Container.zig");
const Padding = @import("Padding.zig");
const Size = @import("Size.zig");

alignment: ?Alignment,
border: ?Border,
child: ?Container,
color: ?Color,
expanded: bool,
padding: ?Padding,
size: ?Size,

pub fn init(expanded: bool, alignment: ?Alignment, border: ?Border, child: ?Container, color: ?Color, padding: ?Padding, size: ?Size) Self {
    return .{
        .alignment = alignment,
        .border = border,
        .child = child,
        .color = color,
        .expanded = expanded,
        .padding = padding,
        .size = size,
    };
}
