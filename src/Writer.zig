const Self = @This();
const std = @import("std");
const c = @cImport({
    @cInclude("hpdf.h");
});
const Pdf = @import("Pdf.zig");
const Date = @import("Date.zig");
const CompressionMode = @import("compression.zig").Mode;
const EncryptionMode = @import("encryption.zig").Mode;
const PermissionName = @import("permission.zig").Name;
const Page = @import("Pdf/Page.zig");
const Size = @import("Pdf/Size.zig");
const Color = @import("Pdf/Color.zig");
const Rgb = @import("Pdf/Rgb.zig");

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
    _ = self;
    _ = hpdf;

    if (page.size.width) |width| {
        _ = c.HPDF_Page_SetWidth(hpage, width);
    }

    if (page.size.height) |height| {
        _ = c.HPDF_Page_SetHeight(hpage, height);
    }

    const width = c.HPDF_Page_GetWidth(hpage);
    const height = c.HPDF_Page_GetHeight(hpage);

    if (page.color.value) |hex| {
        const rgb = try Rgb.hex(hex);
        _ = c.HPDF_Page_SetRGBFill(hpage, @intToFloat(f32, rgb.red) / 255, @intToFloat(f32, rgb.green) / 255, @intToFloat(f32, rgb.blue) / 255);
        _ = c.HPDF_Page_MoveTo(hpage, 0, 0);
        _ = c.HPDF_Page_LineTo(hpage, 0, height);
        _ = c.HPDF_Page_LineTo(hpage, width, height);
        _ = c.HPDF_Page_LineTo(hpage, width, 0);
        _ = c.HPDF_Page_Fill(hpage);
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
        Page.init(Size.init(@as(f32, 100), @as(f32, 100)), Color.init(null)),
        Page.init(Size.init(@as(f32, 595), @as(f32, 842)), Color.init("CCECCC")),
        Page.init(Size.init(@as(f32, 842), @as(f32, 595)), Color.init(null)),
    };

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "demo1", CompressionMode.image, "password", null, EncryptionMode.Revision2, null, &permissions, &pages);
    const pdfWriter = init(pdf);
    try pdfWriter.save("/tmp/zig-pdf.pdf");

    // TODO: Cleanup file
    // TODO: 一時ディレクトリw std.testing.tmpDir から取得できないか!?
}
