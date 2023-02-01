const Self = @This();
const std = @import("std");
const c = @cImport({
    @cInclude("hpdf.h");
});
const Border = @import("Pdf/Border.zig");
const Box = @import("Pdf/Box.zig");
const Color = @import("Pdf/Color.zig");
const CompressionMode = @import("Compression.zig").CompressionMode;
const Container = @import("Pdf/Container.zig").Container;
const Date = @import("Date.zig");
const EncryptionMode = @import("Encryption.zig").EncryptionMode;
const Padding = @import("Pdf/Padding.zig");
const Page = @import("Pdf/Page.zig");
const Pdf = @import("Pdf.zig");
const PermissionName = @import("Permission.zig").PermissionName;
const Rect = @import("Pdf/Rect.zig");
const Rgb = @import("Pdf/Rgb.zig");
const Size = @import("Pdf/Size.zig");

pdf: Pdf,

pub fn init(pdf: Pdf) Self {
    return .{
        .pdf = pdf,
    };
}

pub fn save(self: Self, file_name: []const u8) !void {
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

fn render_page(self: Self, hpdf: c.HPDF_Doc, hpage: c.HPDF_Page, page: Page) !void {
    _ = c.HPDF_Page_SetWidth(hpage, page.frame.width);
    _ = c.HPDF_Page_SetHeight(hpage, page.frame.height);

    if (page.background_color) |background_color| {
        try self.draw_background(hpage, background_color, page.frame);
    }

    if (page.border) |border| {
        try self.draw_border(hpage, border, page.bounds);
    }

    try self.render_box(hpdf, hpage, page.bounds, page.container);
}

fn render_box(self: Self, hpdf: c.HPDF_Doc, hpage: c.HPDF_Page, parentRect: Rect, box: Box) !void {
    _ = hpdf;

    // Layout behavior
    // https://api.flutter.dev/flutter/widgets/Container-class.html
    // ボックス レイアウト モデルの概要については、BoxConstraints を参照してください。
    // Container は多数の他のウィジェットをそれぞれ独自のレイアウト動作と組み合わせているため、Container のレイアウト動作はいくぶん複雑です。
    //
    // 概要: コンテナーは、配置を尊重し、子に合わせてサイズを変更し、幅、高さ、および制約を尊重し、親に合わせて拡張し、できるだけ小さくしようとします。
    // すなわち：
    // ・ウィジェットに子、高さ、幅、制約がなく、親が無制限の制約を提供する場合、Container はサイズをできるだけ小さくしようとします。
    // ・ウィジェットに子と配置がなく、高さ、幅、または制約が指定されている場合、コンテナーは、これらの制約と親の制約の組み合わせを考慮して、できるだけ小さくしようとします。
    // ・ウィジェットに子、高さ、幅、制約、配置がなく、親が制限付き制約を提供している場合、Container は親によって提供された制約に適合するように拡張されます。
    //
    // ・ウィジェットに位置合わせがあり、親が無制限の制約を提供している場合、コンテナは子に合わせてサイズを変更しようとします。
    // ・ウィジェットに位置合わせがあり、親が制限付きの制約を提供している場合、コンテナは親に合わせて拡張しようとし、位置合わせに従って自身の中に子を配置します。
    //
    // ・それ以外の場合、ウィジェットには子がありますが、高さ、幅、制約、および配置はなく、コンテナは親から子に制約を渡し、子に合わせてサイズを変更します。
    // ・これらのプロパティのドキュメントで説明されているように、margin および padding プロパティもレイアウトに影響します。 (これらの効果は、上記のルールを単に拡張するだけです。) 装飾は、暗黙的にパディングを増やすことができます (たとえば、BoxDecoration の境界線がパディングに貢献します)。 装飾.パディングを参照してください。

    const point = parentRect.origin;
    const size = box.size orelse parentRect.size;
    const rect = Rect.init(point.x, point.y, size.width, size.height);

    if (box.border) |border| {
        try self.draw_border(hpage, border, rect);
    }

    // TODO
    // if (box.background_color) |background_color| {
    //     try self.draw_background(hpage, background_color, rect);
    // }
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

    if (border.top != 0 and border.right != 0 and border.bottom != 0 and border.left != 0) {
        _ = c.HPDF_Page_SetLineWidth(hpage, (border.top + border.right + border.bottom + border.left) / 4);
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
        Page.init(Box.init(false, null, null, null, null, null, null), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null),
        Page.init(Box.init(false, null, null, null, null, null, null), Size.init(@as(f32, 595), @as(f32, 842)), Color.init("EEEEEE"), Padding.init(10, 10, 10, 10), Border.init(Color.init("009000"), 1, 1, 1, 1)),
        Page.init(Box.init(false, null, Border.init(Color.init("f9aa8f"), 10, 10, 10, 10), null, null, null, Size.init(500, 500)), Size.init(@as(f32, 595), @as(f32, 842)), Color.init("EFEFEF"), Padding.init(10, 10, 10, 10), Border.init(Color.init("009000"), 1, 1, 1, 1)),
    };

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "demo1", CompressionMode.image, "password", null, EncryptionMode.Revision2, null, &permissions, &pages);
    const pdfWriter = init(pdf);
    try pdfWriter.save("demo/demo.pdf");

    // TODO: Cleanup file
    // TODO: 一時ディレクトリw std.testing.tmpDir から取得できないか!?
}
