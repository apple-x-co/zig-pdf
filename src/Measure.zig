const Self = @This();
const std = @import("std");
const c = @cImport({
    @cInclude("hpdf.h");
});
const Font = @import("Pdf/Font.zig");
const Size = @import("Pdf/Size.zig");
const TextMetrics = @import("Pdf/TextMetrics.zig");

pub fn image(file_path: []const u8) Size {
    const hpdf = c.HPDF_New(null, null);
    defer c.HPDF_Free(hpdf);

    const extension = std.fs.path.extension(file_path);
    const himage = if (std.mem.eql(u8, extension, ".png")) c.HPDF_LoadPngImageFromFile2(hpdf, file_path.ptr) else c.HPDF_LoadJpegImageFromFile(hpdf, file_path.ptr);
    const imageWidth: f32 = @intToFloat(f32, c.HPDF_Image_GetWidth(himage));
    const imageHeight: f32 = @intToFloat(f32, c.HPDF_Image_GetHeight(himage));

    return Size.init(imageWidth, imageHeight);
}

pub fn text(string: []const u8, text_size: f32, font: Font.Font, char_space: f32, word_space: f32) TextMetrics {
    const hpdf = c.HPDF_New(null, null);
    _ = c.HPDF_UseJPFonts(hpdf);
    _ = c.HPDF_UseJPEncodings(hpdf);
    defer c.HPDF_Free(hpdf);

    var hfont: c.HPDF_Font = undefined;
    switch (font) {
        .named_font => {
            const named_font = font.named_font;
            hfont = c.HPDF_GetFont(hpdf, named_font.name.ptr, if (named_font.encoding_name == null) null else named_font.encoding_name.?.ptr);
        },
        .ttc => {
            const ttc = font.ttc;
            const name = c.HPDF_LoadTTFontFromFile2(hpdf, ttc.file_path.ptr, ttc.index, if (ttc.embedding) c.HPDF_TRUE else c.HPDF_FALSE);
            hfont = c.HPDF_GetFont(hpdf, name, if (ttc.encoding_name == null) null else ttc.encoding_name.?.ptr);
        },
        .ttf => {
            const ttf = font.ttf;
            const name = c.HPDF_LoadTTFontFromFile(hpdf, ttf.file_path.ptr, if (ttf.embedding) c.HPDF_TRUE else c.HPDF_FALSE);
            hfont = c.HPDF_GetFont(hpdf, name, if (ttf.encoding_name == null) null else ttf.encoding_name.?.ptr);
        },
        .type1 => {
            const type1 = font.type1;
            const name = c.HPDF_LoadType1FontFromFile(hpdf, type1.arm_file_path.ptr, type1.data_file_path.ptr);
            hfont = c.HPDF_GetFont(hpdf, name, if (type1.encoding_name == null) null else type1.encoding_name.?.ptr);
        },
    }

    const text_len = @intCast(c_uint, string.len);
    const text_width = c.HPDF_Font_TextWidth(hfont, string.ptr, text_len);
    const width = ((@intToFloat(f32, text_width.width) / 1000) * text_size) + (word_space * @intToFloat(f32, text_width.numwords - 1)) + (char_space * @intToFloat(f32, text_width.numchars - 1));
    const descent = (@intToFloat(f32, c.HPDF_Font_GetDescent(hfont) * -1) / 1000) * text_size;
    const b_box = c.HPDF_Font_GetBBox(hfont);
    const line_height = ((b_box.top + (b_box.bottom * -1)) / 1000) * text_size;

    return TextMetrics.init(descent, line_height, width);
}
