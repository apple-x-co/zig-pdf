const Self = @This();
pub const Box = @import("Box.zig");
pub const Col = @import("Col.zig");
pub const Image = @import("Image.zig");
pub const PositionedBox = @import("PositionedBox.zig");
pub const Row = @import("Row.zig");
pub const Text = @import("Text.zig");

pub const Container = union(enum) {
    box: Box,
    col: Col,
    image: Image,
    positioned_box: PositionedBox,
    row: Row,
    text: Text,
};

pub fn make(container: anytype) Container {
    return switch (@TypeOf(container)) {
        Box => Container{ .box = container },
        Col => Container{ .col = container },
        Image => Container{ .image = container },
        PositionedBox => Container{ .positioned_box = container },
        Row => Container{ .row = container },
        Text => Container{ .text = container },
        else => @panic("unexpected"),
    };
}
