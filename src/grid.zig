const std = @import("std");
const c = @cImport({
    @cInclude("hpdf.h");
});

pub fn printGrid(pdf: c.HPDF_Doc, page: c.HPDF_Page) void {
    const height: f32 = c.HPDF_Page_GetHeight(page);
    const width: f32 = c.HPDF_Page_GetWidth(page);
    const font = c.HPDF_GetFont(pdf, "Helvetica", null);
    var x: u64 = 0;
    var y: u64 = 0;

    _ = c.HPDF_Page_SetFontAndSize(page, font, 5);
    _ = c.HPDF_Page_SetGrayFill(page, 0.5);
    _ = c.HPDF_Page_SetGrayStroke(page, 0.8);

    // Draw horizontal lines
    y = 0;
    while (@intToFloat(f32, y) < height) : (y += 5) {
        if (y % 10 == 0) {
            _ = c.HPDF_Page_SetLineWidth(page, 0.5);
        } else {
            if (c.HPDF_Page_GetLineWidth(page) != 0.25)
                _ = c.HPDF_Page_SetLineWidth(page, 0.25);
        }

        _ = c.HPDF_Page_MoveTo(page, 0, @intToFloat(f32, y));
        _ = c.HPDF_Page_LineTo(page, width, @intToFloat(f32, y));
        _ = c.HPDF_Page_Stroke(page);

        if ((y % 10 == 0) and (y > 0)) {
            _ = c.HPDF_Page_SetGrayStroke(page, 0.5);

            _ = c.HPDF_Page_MoveTo(page, 0, @intToFloat(f32, y));
            _ = c.HPDF_Page_LineTo(page, 5, @intToFloat(f32, y));
            _ = c.HPDF_Page_Stroke(page);

            _ = c.HPDF_Page_SetGrayStroke(page, 0.8);
        }
    }

    // Draw vertical lines
    x = 0;
    while (@intToFloat(f32, x) < width) : (x += 5) {
        if (x % 10 == 0) {
            _ = c.HPDF_Page_SetLineWidth(page, 0.5);
        } else {
            if (c.HPDF_Page_GetLineWidth(page) != 0.25)
                _ = c.HPDF_Page_SetLineWidth(page, 0.25);
        }

        _ = c.HPDF_Page_MoveTo(page, @intToFloat(f32, x), 0);
        _ = c.HPDF_Page_LineTo(page, @intToFloat(f32, x), height);
        _ = c.HPDF_Page_Stroke(page);

        if ((x % 50) == 0 and (x > 0)) {
            _ = c.HPDF_Page_SetGrayStroke(page, 0.5);

            _ = c.HPDF_Page_MoveTo(page, @intToFloat(f32, x), 0);
            _ = c.HPDF_Page_LineTo(page, @intToFloat(f32, x), 5);
            _ = c.HPDF_Page_Stroke(page);

            _ = c.HPDF_Page_MoveTo(page, @intToFloat(f32, x), height);
            _ = c.HPDF_Page_LineTo(page, @intToFloat(f32, x), height - 5);
            _ = c.HPDF_Page_Stroke(page);

            _ = c.HPDF_Page_SetGrayStroke(page, 0.8);
        }
    }

    // Draw horizontal text
    y = 0;
    while (@intToFloat(f32, y) < height) : (y += 5) {
        if ((y % 10) == 0 and (y > 0)) {
            var buf: [12]u8 = undefined;

            _ = c.HPDF_Page_BeginText(page);
            _ = c.HPDF_Page_MoveTextPos(page, 5, @intToFloat(f32, y - 2));
            var text = std.fmt.bufPrintZ(&buf, "{}", .{y}) catch return;
            _ = c.HPDF_Page_ShowText(page, text.ptr);
            _ = c.HPDF_Page_EndText(page);
        }
    }

    // Draw vertical text
    x = 0;
    while (@intToFloat(f32, x) < width) : (x += 5) {
        if ((x % 50) == 0 and (x > 0)) {
            var buf: [12]u8 = undefined;

            _ = c.HPDF_Page_BeginText(page);
            _ = c.HPDF_Page_MoveTextPos(page, @intToFloat(f32, x), 5);
            var text = std.fmt.bufPrintZ(&buf, "{}", .{x}) catch return;
            _ = c.HPDF_Page_ShowText(page, text.ptr);
            _ = c.HPDF_Page_EndText(page);

            _ = c.HPDF_Page_BeginText(page);
            _ = c.HPDF_Page_MoveTextPos(page, @intToFloat(f32, x), height - 10);
            _ = c.HPDF_Page_ShowText(page, text.ptr);
            _ = c.HPDF_Page_EndText(page);
        }
    }

    _ = c.HPDF_Page_SetGrayFill(page, 0);
    _ = c.HPDF_Page_SetGrayStroke(page, 0);
}
