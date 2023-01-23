const Self = @This();
const std = @import("std");
const c = @cImport({
    @cInclude("hpdf.h");
});
const Pdf = @import("Pdf.zig");

pdf: Pdf,

pub fn init(pdf: Pdf) Self {
    return .{
        .pdf = pdf,
    };
}

pub fn save(self: Self, file_name: []const u8) void {
    const hpdf = c.HPDF_New(null, null); // FIXME: self.error_handler を指定するとエラーになる
    defer c.HPDF_Free(hpdf);

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

    const hpage = c.HPDF_AddPage(hpdf);
    _ = hpage;

    _ = c.HPDF_SaveToFile(hpdf, file_name.ptr);
}

fn error_handler(error_no: c.HPDF_STATUS, detail_no: c.HPDF_STATUS, user_data: ?*anyopaque) callconv(.C) void {
    _ = user_data;

    const stdErr = std.io.getStdErr();
    std.fmt.format(stdErr, "ERROR: error_no={}, detail_no={}\n", .{ error_no, detail_no }) catch unreachable;
}

test {
    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "demo1", "all", "Revision2", null);
    const pdfWriter = init(pdf);
    pdfWriter.save("/tmp/zig-pdf.pdf");

    // TODO: Cleanup file
}
