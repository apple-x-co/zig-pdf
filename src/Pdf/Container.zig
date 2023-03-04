const Self = @This();
pub const Box = @import("Box.zig");
pub const Column = @import("Column.zig");
pub const Flexible = @import("Flexible.zig");
pub const Image = @import("Image.zig");
pub const PositionedBox = @import("PositionedBox.zig");
pub const Row = @import("Row.zig");
pub const Text = @import("Text.zig");

pub const Container = union(enum) {
    box: Box,
    column: Column,
    flexible: Flexible,
    image: Image,
    positioned_box: PositionedBox,
    row: Row,
    text: Text,

    pub fn getId(self: Container) u32 {
        return switch (self) {
            Container.box => self.box.id,
            Container.column => self.column.id,
            Container.flexible => self.flexible.id,
            Container.image => self.image.id,
            Container.positioned_box => self.positioned_box.id,
            Container.row => self.row.id,
            Container.text => self.text.id,
        };
    }
};

pub fn wrap(container: anytype) Container {
    return switch (@TypeOf(container)) {
        Box => Container{ .box = container },
        Column => Container{ .column = container },
        Flexible => Container{ .flexible = container },
        Image => Container{ .image = container },
        PositionedBox => Container{ .positioned_box = container },
        Row => Container{ .row = container },
        Text => Container{ .text = container },
        else => @panic("unexpected"),
    };
}
