const Self = @This();
const std = @import("std");
const c = @cImport({
    @cInclude("hpdf.h");
});
const grid = @import("grid.zig");
const Alignment = @import("Pdf/Alignment.zig");
const Border = @import("Pdf/Border.zig");
const Color = @import("Pdf/Color.zig");
const CompressionMode = @import("Compression.zig").CompressionMode;
const Container = @import("Pdf/Container.zig");
const Date = @import("Date.zig");
const EncryptionMode = @import("Encryption.zig").EncryptionMode;
const Padding = @import("Pdf/Padding.zig");
const Page = @import("Pdf/Page.zig");
const Pdf = @import("Pdf.zig");
const PermissionName = @import("Permission.zig").PermissionName;
const Rect = @import("Pdf/Rect.zig");
const Rgb = @import("Pdf/Rgb.zig");
const Size = @import("Pdf/Size.zig");

allocator: std.mem.Allocator,
drawing_rect_map: std.AutoHashMap(u32, Rect),
pdf: Pdf,

pub fn init(allocator: std.mem.Allocator, pdf: Pdf) Self {
    return .{
        .allocator = allocator,
        .drawing_rect_map = std.AutoHashMap(u32, Rect).init(allocator),
        .pdf = pdf,
    };
}

pub fn deinit(self: *Self) void {
    self.drawing_rect_map.deinit();
}

pub fn save(self: *Self, file_name: []const u8) !void {
    const hpdf = c.HPDF_New(null, null); // FIXME: self.error_handler を指定するとエラーになる
    defer c.HPDF_Free(hpdf);

    self.set_attributes(hpdf);

    for (self.pdf.pages) |page| {
        const hpage = c.HPDF_AddPage(hpdf);

        try self.render_page(hpdf, hpage, page);
    }

    _ = c.HPDF_SaveToFile(hpdf, file_name.ptr);
}

fn set_attributes(self: Self, hpdf: c.HPDF_Doc) void {
    const date = Date.now();
    const hdate = c.HPDF_Date{ .year = date.year, .month = date.month, .day = date.day, .hour = date.hours, .minutes = date.minutes, .seconds = date.seconds, .ind = ' ', .off_hour = 0, .off_minutes = 0 };

    _ = c.HPDF_SetInfoDateAttr(hpdf, c.HPDF_INFO_CREATION_DATE, hdate);
    _ = c.HPDF_SetInfoDateAttr(hpdf, c.HPDF_INFO_MOD_DATE, hdate);
    _ = c.HPDF_UseJPFonts(hpdf);
    _ = c.HPDF_UseJPEncodings(hpdf);

    if (self.pdf.author) |author| {
        _ = c.HPDF_SetInfoAttr(hpdf, c.HPDF_INFO_AUTHOR, author.ptr);
    }

    if (self.pdf.creator) |creator| {
        _ = c.HPDF_SetInfoAttr(hpdf, c.HPDF_INFO_CREATOR, creator.ptr);
    }

    if (self.pdf.title) |title| {
        _ = c.HPDF_SetInfoAttr(hpdf, c.HPDF_INFO_TITLE, title.ptr);
    }

    if (self.pdf.subject) |subject| {
        _ = c.HPDF_SetInfoAttr(hpdf, c.HPDF_INFO_SUBJECT, subject.ptr);
    }

    if (self.pdf.compression_mode) |compression_mode| {
        const hcompression_mode: c.HPDF_UINT = switch (compression_mode) {
            CompressionMode.all => c.HPDF_COMP_ALL,
            CompressionMode.image => c.HPDF_COMP_IMAGE,
            CompressionMode.text => c.HPDF_COMP_TEXT,
            CompressionMode.metadata => c.HPDF_COMP_METADATA,
            else => c.HPDF_COMP_NONE,
        };
        _ = c.HPDF_SetCompressionMode(hpdf, hcompression_mode);
    }

    if (self.pdf.owner_password) |owner_password| {
        if (self.pdf.user_password) |user_password| {
            _ = c.HPDF_SetPassword(hpdf, owner_password.ptr, user_password.ptr);
        } else {
            _ = c.HPDF_SetPassword(hpdf, owner_password.ptr, null);
        }

        if (self.pdf.encryption_mode) |encryption_mode| {
            const hencryption: c.HPDF_UINT = switch (encryption_mode) {
                EncryptionMode.Revision2 => c.HPDF_ENCRYPT_R2,
                EncryptionMode.Revision3 => c.HPDF_ENCRYPT_R3,
            };
            _ = c.HPDF_SetEncryptionMode(hpdf, hencryption, self.pdf.encryption_length orelse 5);
        }
    }

    if (self.pdf.permission_names) |_| {
        var hpermission: c.HPDF_UINT = 0;
        for (self.pdf.permission_names.?) |permission_name| {
            switch (permission_name) {
                PermissionName.read => {
                    hpermission |= c.HPDF_ENABLE_READ;
                },
                PermissionName.print => {
                    hpermission |= c.HPDF_ENABLE_PRINT;
                },
                PermissionName.edit_all => {
                    hpermission |= c.HPDF_ENABLE_EDIT_ALL;
                },
                PermissionName.copy => {
                    hpermission |= c.HPDF_ENABLE_COPY;
                },
                PermissionName.edit => {
                    hpermission |= c.HPDF_ENABLE_EDIT;
                },
            }
        }
        _ = c.HPDF_SetPermission(hpdf, hpermission);
    }
}

fn render_page(self: *Self, hpdf: c.HPDF_Doc, hpage: c.HPDF_Page, page: Page) !void {
    _ = c.HPDF_Page_SetWidth(hpage, page.frame.width);
    _ = c.HPDF_Page_SetHeight(hpage, page.frame.height);

    grid.print_grid(hpdf, hpage); // for debug

    if (page.background_color) |background_color| {
        try self.draw_background(hpage, background_color, page.frame);
    }

    if (page.border) |border| {
        try self.draw_border(hpage, border, page.bounds);
    }

    try self.render_container(hpdf, hpage, page.bounds, page.alignment, Container.make(page.container));

    // const drawing_rect = try self.render_box(hpdf, hpage, page.bounds, page.alignment, page.container);
    // try self.drawing_rect_map.put(page.container.id, drawing_rect);

    // // debug
    // try self.draw_border(hpage, Border.init(Color.init("FF0000"), Border.Style.dash, 0.5, 0.5, 0.5, 0.5), drawing_rect);
    // _ = c.HPDF_Page_BeginText(hpage);
    // _ = c.HPDF_Page_SetRGBFill(hpage, 1.0, 0.0, 0.0);
    // _ = c.HPDF_Page_SetTextRenderingMode(hpage, c.HPDF_FILL);
    // // _ = c.HPDF_Page_MoveTextPos(hpage, drawing_rect.minX, drawing_rect.minY);
    // // _ = c.HPDF_Page_ShowText(hpage, "HELLO!!");
    // _ = c.HPDF_Page_TextOut(hpage, drawing_rect.minX, drawing_rect.minY, "Page container's drawable rect.");
    // _ = c.HPDF_Page_EndText(hpage);
    // // debug
}

fn render_container(self: *Self, hpdf: c.HPDF_Doc, hpage: c.HPDF_Page, rect: Rect, alignment: ?Alignment, container: Container.Container) !void {
    switch (container) {
        .box => {
            const box = container.box;
            const drawing_rect = try self.render_box(hpdf, hpage, rect, alignment, box);
            try self.drawing_rect_map.put(box.id, drawing_rect);

            // debug
            try self.draw_border(hpage, Border.init(Color.init("FF0000"), Border.Style.dash, 0.5, 0.5, 0.5, 0.5), drawing_rect);
            _ = c.HPDF_Page_BeginText(hpage);
            _ = c.HPDF_Page_SetRGBFill(hpage, 1.0, 0.0, 0.0);
            _ = c.HPDF_Page_SetTextRenderingMode(hpage, c.HPDF_FILL);
            // _ = c.HPDF_Page_MoveTextPos(hpage, drawing_rect.minX, drawing_rect.minY);
            // _ = c.HPDF_Page_ShowText(hpage, "HELLO!!");
            _ = c.HPDF_Page_TextOut(hpage, drawing_rect.minX, drawing_rect.minY, "Page container's drawable rect.");
            _ = c.HPDF_Page_EndText(hpage);
            // debug
        },
        .positioned_box => {},
        .col => {},
        .row => {},
        .image => {},
        .text => {},
    }
}

fn render_box(self: Self, hpdf: c.HPDF_Doc, hpage: c.HPDF_Page, parentRect: Rect, alignment: ?Alignment, box: Container.Box) !Rect {
    _ = hpdf;

    const point = parentRect.origin;
    const size = box.size orelse parentRect.size;
    const pad = box.padding orelse Padding.zeroPadding;

    var frame = Rect.init(point.x, parentRect.maxY - size.height, if (box.expanded) (parentRect.size.width / size.width) * size.width else size.width, size.height); // 座標原点を左上にして計算

    if (box.size != null and alignment != null) {
        const x = parentRect.midX - (alignment.?.x * (box.size.?.width / 2) + (box.size.?.width / 2));
        const y = parentRect.midY - (alignment.?.y * (box.size.?.height / 2) + (box.size.?.height / 2));
        frame = Rect.init(x, y, box.size.?.width, box.size.?.height);
    }

    const bounds = Rect.init(0, 0, frame.width - pad.left - pad.right, frame.height - pad.top - pad.bottom);

    if (box.border) |border| {
        try self.draw_border(hpage, border, frame);
    }

    if (box.background_color) |background_color| {
        try self.draw_background(hpage, background_color, frame);
    }

    return Rect.init(frame.minX + pad.left, frame.minY + pad.top, bounds.width, bounds.height);
}

fn draw_background(self: Self, hpage: c.HPDF_Page, color: Color, rect: Rect) !void {
    _ = self;

    if (color.value) |hex| {
        const rgb = try Rgb.hex(hex);
        _ = c.HPDF_Page_SetRGBFill(hpage, @intToFloat(f32, rgb.red) / 255, @intToFloat(f32, rgb.green) / 255, @intToFloat(f32, rgb.blue) / 255);
        _ = c.HPDF_Page_MoveTo(hpage, rect.minX, rect.minY);
        _ = c.HPDF_Page_LineTo(hpage, rect.minX, rect.maxY);
        _ = c.HPDF_Page_LineTo(hpage, rect.maxX, rect.maxY);
        _ = c.HPDF_Page_LineTo(hpage, rect.maxX, rect.minY);
        _ = c.HPDF_Page_Fill(hpage);
    }
}

fn draw_border(self: Self, hpage: c.HPDF_Page, border: Border, rect: Rect) !void {
    _ = self;

    const rgb = try Rgb.hex(border.color.value.?);
    const red = @intToFloat(f32, rgb.red) / 255;
    const green = @intToFloat(f32, rgb.green) / 255;
    const blue = @intToFloat(f32, rgb.blue) / 255;

    const DASH_STYLE1: []const c.HPDF_REAL = &.{
        3,
    };

    if (border.style == Border.Style.dash) {
        _ = c.HPDF_Page_SetDash(hpage, DASH_STYLE1.ptr, 1, 1);
    } else {
        _ = c.HPDF_Page_SetDash(hpage, null, 0, 0);
    }

    if (border.top != 0 and border.right != 0 and border.bottom != 0 and border.left != 0) {
        const width = (border.top + border.right + border.bottom + border.left) / 4;
        _ = c.HPDF_Page_SetLineWidth(hpage, width);
        _ = c.HPDF_Page_SetRGBStroke(hpage, red, green, blue);
        _ = c.HPDF_Page_Rectangle(hpage, rect.minX, rect.minY, rect.width, rect.height);
        _ = c.HPDF_Page_Stroke(hpage);
        return;
    }

    if (border.top != 0) {
        _ = c.HPDF_Page_SetLineWidth(hpage, border.top);
        _ = c.HPDF_Page_SetRGBStroke(hpage, red, green, blue);
        _ = c.HPDF_Page_MoveTo(hpage, rect.minX, rect.maxY);
        _ = c.HPDF_Page_LineTo(hpage, rect.maxX, rect.maxY);
        _ = c.HPDF_Page_Stroke(hpage);
    }

    if (border.right != 0) {
        _ = c.HPDF_Page_SetLineWidth(hpage, border.right);
        _ = c.HPDF_Page_SetRGBStroke(hpage, red, green, blue);
        _ = c.HPDF_Page_MoveTo(hpage, rect.maxX, rect.maxY);
        _ = c.HPDF_Page_LineTo(hpage, rect.maxX, rect.minY);
        _ = c.HPDF_Page_Stroke(hpage);
    }

    if (border.bottom != 0) {
        _ = c.HPDF_Page_SetLineWidth(hpage, border.bottom);
        _ = c.HPDF_Page_SetRGBStroke(hpage, red, green, blue);
        _ = c.HPDF_Page_MoveTo(hpage, rect.maxX, rect.minY);
        _ = c.HPDF_Page_LineTo(hpage, rect.minX, rect.minY);
        _ = c.HPDF_Page_Stroke(hpage);
    }

    if (border.left != 0) {
        _ = c.HPDF_Page_SetLineWidth(hpage, border.left);
        _ = c.HPDF_Page_SetRGBStroke(hpage, red, green, blue);
        _ = c.HPDF_Page_MoveTo(hpage, rect.minX, rect.minY);
        _ = c.HPDF_Page_LineTo(hpage, rect.minX, rect.maxY);
        _ = c.HPDF_Page_Stroke(hpage);
    }
}

fn error_handler(error_no: c.HPDF_STATUS, detail_no: c.HPDF_STATUS, user_data: ?*anyopaque) callconv(.C) void {
    _ = user_data;

    const stdErr = std.io.getStdErr();
    std.fmt.format(stdErr, "ERROR: error_no={}, detail_no={}\n", .{ error_no, detail_no }) catch unreachable;
}

test {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.copy,
        PermissionName.print,
    };

    var pages = [_]Page{
        Page.init(Container.Box.init(false, null, null, null, null, null, null), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.Box.init(false, null, null, null, null, null, null), Size.init(@as(f32, 595), @as(f32, 842)), Color.init("EEEEEE"), Padding.init(10, 10, 10, 10), null, Border.init(Color.init("000090"), Border.Style.solid, 1, 1, 1, 1)),
        Page.init(Container.Box.init(false, null, Color.init("fef1ec"), Border.init(Color.init("f9aa8f"), Border.Style.solid, 1, 1, 1, 1), null, Padding.init(25, 25, 25, 25), Size.init(550, 550)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(50, 50, 50, 50), null, Border.init(Color.init("009000"), Border.Style.solid, 1, 1, 1, 1)),
        Page.init(Container.Box.init(true, null, Color.init("fef1ec"), Border.init(Color.init("f9aa8f"), Border.Style.solid, 1, 1, 1, 1), null, Padding.init(25, 25, 25, 25), Size.init(550, 550)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(50, 50, 50, 50), null, Border.init(Color.init("009000"), Border.Style.solid, 1, 1, 1, 1)),
        Page.init(Container.Box.init(false, null, Color.init("fef1ec"), null, null, null, Size.init(100, 100)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, Alignment.center, null),
        Page.init(Container.Box.init(false, null, Color.init("fef1ec"), null, null, null, Size.init(300, 100)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, Alignment.center, null),
        Page.init(Container.Box.init(false, null, Color.init("fef1ec"), null, null, null, Size.init(500, 100)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, Alignment.center, null),
    };

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "demo1", CompressionMode.image, "password", null, EncryptionMode.Revision2, null, &permissions, &pages);
    var pdfWriter = init(std.testing.allocator, pdf);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/demo.pdf");

    // TODO: Cleanup file
    // TODO: 一時ディレクトリw std.testing.tmpDir から取得できないか!?
}
