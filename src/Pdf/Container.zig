const Self = @This();
const std = @import("std");
const Box = @import("Box.zig");
const Col = @import("Col.zig");
const Image = @import("Image.zig");
const PositionedBox = @import("PositionedBox.zig");
const Row = @import("Row.zig");
const Text = @import("Text.zig");

pub const Container = union(enum) {
    box: Box,
    col: Col,
    image: Image,
    positioned_box: PositionedBox,
    row: Row,
    text: Text,
};
