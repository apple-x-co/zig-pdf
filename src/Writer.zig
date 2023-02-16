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
const default_font_encode_name = "90ms-RKSJ-H";
const default_font_name = "MS-Gothic";
const default_text_size: f32 = 8;
const EncryptionMode = @import("Encryption.zig").EncryptionMode;
const Font = @import("Pdf/Font.zig");
const Padding = @import("Pdf/Padding.zig");
const Page = @import("Pdf/Page.zig");
const Pdf = @import("Pdf.zig");
const PermissionName = @import("Permission.zig").PermissionName;
const Rect = @import("Pdf/Rect.zig");
const Rgb = @import("Pdf/Rgb.zig");
const Size = @import("Pdf/Size.zig");

allocator: std.mem.Allocator,
content_frame_map: std.AutoHashMap(u32, Rect),
// font_map: std.StringHashMap(c.HPDF_Font),
is_debug: bool,
pdf: Pdf,

pub fn init(allocator: std.mem.Allocator, pdf: Pdf, is_debug: bool) Self {
    return .{
        .allocator = allocator,
        .content_frame_map = std.AutoHashMap(u32, Rect).init(allocator),
        // .font_map = std.StringHashMap(c.HPDF_Font).init(allocator),
        .is_debug = is_debug,
        .pdf = pdf,
    };
}

pub fn deinit(self: *Self) void {
    self.content_frame_map.deinit();
    // self.font_map.deinit();
}

pub fn save(self: *Self, file_name: []const u8) !void {
    const hpdf = c.HPDF_New(errorEandler, null);
    defer c.HPDF_Free(hpdf);

    self.setPdfAttributes(hpdf);

    // const font: c.HPDF_Font = c.HPDF_GetFont(hpdf, "MS-Gothic", "90ms-RKSJ-H");
    // try self.font_map.put("default", font);
    // _ = try self.font_map.get("default"); // FIXME: error: expected error union type, found '?[*c].xxxxx.zig-cache.o.f626383f61633cb0db6ac93886e75491.cimport.struct__HPDF_Dict_Rec'

    for (self.pdf.pages) |page| {
        const hpage = c.HPDF_AddPage(hpdf);

        try self.renderPage(hpdf, hpage, page);
    }

    _ = c.HPDF_SaveToFile(hpdf, file_name.ptr);
}

fn setPdfAttributes(self: Self, hpdf: c.HPDF_Doc) void {
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

fn renderPage(self: *Self, hpdf: c.HPDF_Doc, hpage: c.HPDF_Page, page: Page) !void {
    _ = c.HPDF_Page_SetWidth(hpage, page.frame.width);
    _ = c.HPDF_Page_SetHeight(hpage, page.frame.height);

    if (self.is_debug) {
        grid.printGrid(hpdf, hpage);
    }

    if (page.background_color) |background_color| {
        try self.drawBackground(hpage, background_color, page.frame);
    }

    if (page.border) |border| {
        try self.drawBorder(hpage, border, page.content_frame);
    }

    try self.renderContainer(hpdf, hpage, page.content_frame, page.alignment, page.container);
}

fn renderContainer(self: *Self, hpdf: c.HPDF_Doc, hpage: c.HPDF_Page, rect: Rect, alignment: ?Alignment, container: Container.Container) !void {
    switch (container) {
        .box => {
            const box = container.box;
            const content_frame = try self.renderBox(hpdf, hpage, rect, alignment, box);
            try self.content_frame_map.put(box.id, content_frame);

            if (self.is_debug) {
                try self.drawBorder(hpage, Border.init(Color.init("FF0000"), Border.Style.dash, 0.5, 0.5, 0.5, 0.5), content_frame);
                _ = c.HPDF_Page_BeginText(hpage);
                _ = c.HPDF_Page_SetRGBFill(hpage, 1.0, 0.0, 0.0);
                _ = c.HPDF_Page_SetTextRenderingMode(hpage, c.HPDF_FILL);
                _ = c.HPDF_Page_TextOut(hpage, content_frame.minX, content_frame.minY, "Page container's drawable rect.");
                _ = c.HPDF_Page_EndText(hpage);
            }
        },
        .positioned_box => {
            const positioned_box = container.positioned_box;
            const content_frame = try self.renderPositionedBox(hpdf, hpage, rect, positioned_box);
            try self.content_frame_map.put(positioned_box.id, content_frame);

            if (self.is_debug) {
                try self.drawBorder(hpage, Border.init(Color.init("0000FF"), Border.Style.dot, 0.5, 0.5, 0.5, 0.5), content_frame);
                _ = c.HPDF_Page_BeginText(hpage);
                _ = c.HPDF_Page_SetRGBFill(hpage, 1.0, 0.0, 0.0);
                _ = c.HPDF_Page_SetTextRenderingMode(hpage, c.HPDF_FILL);
                _ = c.HPDF_Page_TextOut(hpage, content_frame.minX, content_frame.minY, "Positioned box's drawable rect.");
                _ = c.HPDF_Page_EndText(hpage);
            }
        },
        .col => {},
        .row => {},
        .image => {
            const image = container.image;
            const content_frame = try self.renderImage(hpdf, hpage, rect, alignment, image);
            try self.content_frame_map.put(image.id, content_frame);

            if (self.is_debug) {
                try self.drawBorder(hpage, Border.init(Color.init("00FFFF"), Border.Style.dot, 0.5, 0.5, 0.5, 0.5), content_frame);
                _ = c.HPDF_Page_BeginText(hpage);
                _ = c.HPDF_Page_SetRGBFill(hpage, 1.0, 0.0, 0.0);
                _ = c.HPDF_Page_SetTextRenderingMode(hpage, c.HPDF_FILL);
                _ = c.HPDF_Page_TextOut(hpage, content_frame.minX, content_frame.minY, "Image's rect.");
                _ = c.HPDF_Page_EndText(hpage);
            }
        },
        .text => {
            const text = container.text;
            const content_frame = try self.renderText(hpdf, hpage, rect, alignment, text);
            try self.content_frame_map.put(text.id, content_frame);

            if (self.is_debug) {
                try self.drawBorder(hpage, Border.init(Color.init("FF00FF"), Border.Style.dot, 0.5, 0.5, 0.5, 0.5), content_frame);
            }
        },
    }
}

fn renderBox(self: Self, hpdf: c.HPDF_Doc, hpage: c.HPDF_Page, parent_rect: Rect, alignment: ?Alignment, box: Container.Box) !Rect {
    _ = hpdf;

    const size = box.size orelse parent_rect.size;
    const pad = box.padding orelse Padding.zeroPadding;
    const width = if (box.expanded) (parent_rect.size.width / size.width) * size.width else size.width;
    // const height = size.height;
    const height = if (box.expanded) (parent_rect.size.height / size.height) * size.height else size.height;

    var content_frame = parent_rect.offsetLTWH(0, 0, width, height);

    if (box.size != null and alignment != null) {
        const x = (alignment.?.x * (box.size.?.width / 2) + (box.size.?.width / 2)) - (alignment.?.x * parent_rect.width / 2);
        const y = (alignment.?.y * (box.size.?.height / 2) + (box.size.?.height / 2)) - (alignment.?.y * parent_rect.height / 2);
        content_frame = parent_rect.offsetCenterXYWH(x * -1, y * -1, box.size.?.width, box.size.?.height);
    }

    if (box.border) |border| {
        try self.drawBorder(hpage, border, content_frame);
    }

    if (box.background_color) |background_color| {
        try self.drawBackground(hpage, background_color, content_frame);
    }

    return content_frame.insets(pad.top, pad.right, pad.bottom, pad.left);
}

fn renderPositionedBox(self: Self, hpdf: c.HPDF_Doc, hpage: c.HPDF_Page, parent_rect: Rect, positioned_box: Container.PositionedBox) !Rect {
    _ = self;
    _ = hpdf;
    _ = hpage;

    if (positioned_box.size == null) {
        return parent_rect.insets(positioned_box.top orelse 0, positioned_box.right orelse 0, positioned_box.bottom orelse 0, positioned_box.left orelse 0);
    }

    const size = positioned_box.size.?;

    var x: f32 = 0;
    var y: f32 = 0;
    if (positioned_box.left) |left| {
        x = left;
    }
    if (positioned_box.right) |right| {
        x = parent_rect.width - size.width - right;
    }
    if (positioned_box.top) |top| {
        y = top;
    }
    if (positioned_box.bottom) |bottom| {
        y = parent_rect.height - size.height - bottom;
    }

    const content_frame = parent_rect.offsetLTWH(x, y, size.width, size.height);

    return content_frame;
}

fn renderImage(self: Self, hpdf: c.HPDF_Doc, hpage: c.HPDF_Page, parent_rect: Rect, alignment: ?Alignment, image: Container.Image) !Rect {
    _ = self;

    const extension = std.fs.path.extension(image.path);
    const himage = if (std.mem.eql(u8, extension, ".png")) c.HPDF_LoadPngImageFromFile(hpdf, image.path.ptr) else c.HPDF_LoadJpegImageFromFile(hpdf, image.path.ptr);
    const imageWidth: f32 = @intToFloat(f32, c.HPDF_Image_GetWidth(himage));
    const imageHeight: f32 = @intToFloat(f32, c.HPDF_Image_GetHeight(himage));

    const size = image.size orelse Size.init(imageWidth, imageHeight);

    var content_frame = parent_rect.offsetLTWH(0, 0, size.width, size.height);

    if (image.size != null and alignment != null) {
        const x = (alignment.?.x * (image.size.?.width / 2) + (image.size.?.width / 2)) - (alignment.?.x * parent_rect.width / 2);
        const y = (alignment.?.y * (image.size.?.height / 2) + (image.size.?.height / 2)) - (alignment.?.y * parent_rect.height / 2);
        content_frame = parent_rect.offsetCenterXYWH(x * -1, y * -1, image.size.?.width, image.size.?.height);
    }

    _ = c.HPDF_Page_DrawImage(hpage, himage, content_frame.minX, content_frame.minY, content_frame.width, content_frame.height);

    return content_frame;
}

fn renderText(self: Self, hpdf: c.HPDF_Doc, hpage: c.HPDF_Page, parent_rect: Rect, alignment: ?Alignment, text: Container.Text) !Rect {
    _ = self;

    _ = c.HPDF_Page_BeginText(hpage);

    var hfont: c.HPDF_Font = null;
    if (text.font) |font| {
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
    }
    if (hfont == null) {
        hfont = c.HPDF_GetFont(hpdf, default_font_name, default_font_encode_name);
    }

    const text_size = text.text_size orelse default_text_size;
    const word_space = text.word_space orelse 0;
    const char_space = text.char_space orelse 0;
    var soft_wrap = text.soft_wrap;

    _ = c.HPDF_Page_SetFontAndSize(hpage, hfont, text_size);
    _ = c.HPDF_Page_SetWordSpace(hpage, word_space);
    _ = c.HPDF_Page_SetCharSpace(hpage, char_space);

    const text_len = @intCast(c_uint, text.content.len);
    const text_width = c.HPDF_Font_TextWidth(hfont, text.content.ptr, text_len);
    const width = ((@intToFloat(f32, text_width.width) / 1000) * text_size) + (word_space * @intToFloat(f32, text_width.numwords - 1)) + (char_space * @intToFloat(f32, text_width.numchars - 1));
    // const ascent = ((@intToFloat(f32, c.HPDF_Font_GetAscent(hfont)) / 1000) * text_size);
    const descent = (@intToFloat(f32, c.HPDF_Font_GetDescent(hfont) * -1) / 1000) * text_size;
    // const font_height = ascent + descent;
    const b_box = c.HPDF_Font_GetBBox(hfont);
    const line_height = ((b_box.top + (b_box.bottom * -1)) / 1000) * text_size;
    var size = Size.init(width, line_height);

    _ = c.HPDF_Page_SetTextLeading(hpage, line_height);

    if (soft_wrap) {
        // ページ設定で指定した幅の中に配置できる文字の数を計算する - HPDF_Page_MeasureText
        // 指定した幅の中に配置できる文字の数を計算する - HPDF_Font_MeasureText
        var real_width: c.HPDF_REAL = 0;
        // _ = c.HPDF_Page_MeasureText(hpage, text.content.ptr, parent_rect.width, c.HPDF_FALSE, &real_width);
        _ = c.HPDF_Font_MeasureText(hfont, text.content.ptr, text_len, parent_rect.width, text_size, char_space, word_space, c.HPDF_FALSE, &real_width);
        if (size.width - real_width > 1.0) {
            const number_lines = @ceil(size.width / real_width);
            size = Size.init(real_width, line_height * number_lines);
        } else {
            soft_wrap = false;
        }
    }

    var content_frame = parent_rect.offsetLTWH(0, 0, size.width, size.height);

    if (alignment != null) {
        const x = (alignment.?.x * (size.width / 2) + (size.width / 2)) - (alignment.?.x * parent_rect.width / 2);
        const y = (alignment.?.y * (size.height / 2) + (size.height / 2)) - (alignment.?.y * parent_rect.height / 2);
        content_frame = parent_rect.offsetCenterXYWH(x * -1, y * -1, size.width, size.height);
    }

    _ = c.HPDF_Page_SetRGBFill(hpage, 0.0, 0.0, 0.0);
    if (text.color) |text_color| {
        if (text_color.value) |hex| {
            const rgb = try Rgb.hex(hex);
            const red = @intToFloat(f32, rgb.red) / 255;
            const green = @intToFloat(f32, rgb.green) / 255;
            const blue = @intToFloat(f32, rgb.blue) / 255;
            _ = c.HPDF_Page_SetRGBFill(hpage, red, green, blue);
        }
    }

    _ = c.HPDF_Page_SetTextRenderingMode(hpage, c.HPDF_FILL);

    // 指定した領域内にテキストを表示する - HPDF_Page_TextRect
    // 指定した位置にテキストを表示する - HPDF_Page_TextOut
    // ページの現在位置にテキストを表示する - HPDF_Page_ShowText
    if (soft_wrap) {
        // "HPDF_Page_TextRect" は単語の途中で改行されない
        // _ = c.HPDF_Page_TextRect(hpage, content_frame.minX, content_frame.maxY, content_frame.maxX, content_frame.minY, text.content.ptr, c.HPDF_TALIGN_LEFT, null);

        _ = c.HPDF_Page_MoveTextPos(hpage, content_frame.minX, content_frame.maxY - line_height + descent);
        var x: f32 = 0;
        var w: f32 = 0;
        var buf: [2]u8 = undefined;
        for (text.content) |char| {
            var s = try std.fmt.bufPrintZ(&buf, "{u}", .{char});
            x = c.HPDF_Page_GetCurrentTextPos(hpage).x;
            w = emToPoint(@intToFloat(f32, c.HPDF_Font_TextWidth(hfont, s.ptr, 1).width), text_size);
            if (x + w > content_frame.maxX) {
                _ = c.HPDF_Page_MoveToNextLine(hpage);
            }
            _ = c.HPDF_Page_ShowText(hpage, s.ptr);
        }
    } else {
        _ = c.HPDF_Page_TextOut(hpage, content_frame.minX, content_frame.minY + descent, text.content.ptr);
    }

    _ = c.HPDF_Page_EndText(hpage);

    return content_frame;
}

fn drawBackground(self: Self, hpage: c.HPDF_Page, color: Color, rect: Rect) !void {
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

fn drawBorder(self: Self, hpage: c.HPDF_Page, border: Border, rect: Rect) !void {
    _ = self;

    const rgb = try Rgb.hex(border.color.value.?);
    const red = @intToFloat(f32, rgb.red) / 255;
    const green = @intToFloat(f32, rgb.green) / 255;
    const blue = @intToFloat(f32, rgb.blue) / 255;

    switch (border.style) {
        Border.Style.dash => {
            _ = c.HPDF_Page_SetDash(hpage, &[_]c.HPDF_REAL{3}, 1, 1);
        },
        Border.Style.dot => {
            // _ = c.HPDF_Page_SetLineCap (hpage, c.HPDF_ROUND_END);
            _ = c.HPDF_Page_SetDash(hpage, &[_]c.HPDF_REAL{0.5}, 1, 1);
        },
        else => {
            _ = c.HPDF_Page_SetDash(hpage, null, 0, 0);
        },
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

fn emToPoint(em: f32, text_size: f32) f32 {
    return (em / 1000) * text_size;
}

fn errorEandler(error_no: c.HPDF_STATUS, detail_no: c.HPDF_STATUS, user_data: ?*anyopaque) callconv(.C) void {
    _ = user_data;
    std.log.err("ERROR: error_no={}, detail_no={}", .{ error_no, detail_no });
}

test "permission" {
    const permissions = [_]PermissionName{
        PermissionName.read,
    };

    var pages = [_]Page{
        Page.init(Container.wrap(Container.Box.init(false, null, null, null, null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
    };

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "permission", CompressionMode.none, "password", null, EncryptionMode.Revision2, null, &permissions, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/permission.pdf");
}

test "page" {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.edit_all,
    };

    var pages = [_]Page{
        Page.init(Container.wrap(Container.Text.init("Background color #EFEFEF", null, null, null, true, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), Color.init("EFEFEF"), null, null, null),
        Page.init(Container.wrap(Container.Text.init("Padding color (10, 10, 10, 10)", null, null, null, true, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Text.init("Alignment top x left", null, null, null, true, null, null)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.topLeft, null),
        Page.init(Container.wrap(Container.Text.init("Alignment top x center", null, null, null, true, null, null)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.topCenter, null),
        Page.init(Container.wrap(Container.Text.init("Alignment top x right", null, null, null, true, null, null)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.topRight, null),
        Page.init(Container.wrap(Container.Text.init("Alignment center x left", null, null, null, true, null, null)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.centerLeft, null),
        Page.init(Container.wrap(Container.Text.init("Alignment center", null, null, null, true, null, null)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.center, null),
        Page.init(Container.wrap(Container.Text.init("Alignment center x right", null, null, null, true, null, null)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.centerRight, null),
        Page.init(Container.wrap(Container.Text.init("Alignment bottom x left", null, null, null, true, null, null)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.bottomLeft, null),
        Page.init(Container.wrap(Container.Text.init("Alignment bottom x center", null, null, null, true, null, null)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.bottomCenter, null),
        Page.init(Container.wrap(Container.Text.init("Alignment bottom x right", null, null, null, true, null, null)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.bottomRight, null),
        Page.init(Container.wrap(Container.Text.init("Border", null, null, null, true, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, Border.init(Color.init("0FF0FF"), Border.Style.dot, 5, 5, 5, 5)),
        Page.init(Container.wrap(Container.Text.init("All page properties", null, null, null, true, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(50, 50, 50, 50), Alignment.topRight, Border.init(Color.init("FFF00F"), Border.Style.dot, 5, 5, 5, 5)),
    };

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "page", CompressionMode.none, "password", null, EncryptionMode.Revision2, null, &permissions, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/page.pdf");
}

test "box" {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.edit_all,
    };

    var pages = [_]Page{
        Page.init(Container.wrap(Container.Box.init(false, null, null, null, null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Box.init(false, Alignment.center, null, null, null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Box.init(false, null, Color.init("EFEFEF"), null, null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Box.init(false, null, null, Border.init(Color.init("0FF0FF"), Border.Style.dot, 1, 1, 1, 1), null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Box.init(false, null, null, null, null, Padding.init(10, 10, 10, 10), null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Box.init(false, null, null, null, null, null, Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Box.init(false, Alignment.center, Color.init("EFEFEF"), Border.init(Color.init("0FF0FF"), Border.Style.dot, 1, 1, 1, 1), null, Padding.init(10, 10, 10, 10), Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), Alignment.center, null),
        Page.init(Container.wrap(Container.Box.init(false, null, null, null, null, null, Size.init(600, 900))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.Box.init(true, null, null, null, null, null, Size.init(600, 900))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
    };

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "box", CompressionMode.none, "password", null, EncryptionMode.Revision2, null, &permissions, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/box.pdf");
}

test "positioned_box" {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.edit_all,
    };

    var pages = [_]Page{
        Page.init(Container.wrap(Container.PositionedBox.init(50, null, null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(null, 50, null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(null, null, 50, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(null, null, null, 50, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(null, null, null, null, Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(50, 50, 50, 50, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(50, 50, null, null, Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(null, null, 50, 50, Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(null, 50, 50, null, Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
    };

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "positioned_box", CompressionMode.text, "password", null, EncryptionMode.Revision2, null, &permissions, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/positioned_box.pdf");
}

test "image" {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.edit_all,
    };

    var pages = [_]Page{
        Page.init(Container.wrap(Container.Image.init("src/images/sample.jpg", null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.Image.init("src/images/sample.png", null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.Image.init("src/images/sample.png", Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.Image.init("src/images/sample.png", Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, Alignment.center, null),
    };

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "image", CompressionMode.image, "password", null, EncryptionMode.Revision2, null, &permissions, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/image.pdf");
}

test "text" {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.edit_all,
    };

    var pages = [_]Page{
        Page.init(Container.wrap(Container.Text.init("Hello TypogrAphy. (default)", null, null, null, null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.Text.init("Hello TypogrAphy. (change color)", Color.init("FF00FF"), null, null, null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.Text.init("Hello TypogrAphy. (change size)", null, 20, null, null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.Text.init("Hello TypogrAphy. (change font face to helvetica)", null, null, Font.wrap(Font.NamedFont.init("Helvetica", null)), null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.Text.init("Hello TypogrAphy. (change font face to mplus1p)", null, null, Font.wrap(Font.Ttf.init("src/fonts/MPLUS1p-Thin.ttf", true, null)), null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.Text.init("Hello TypogrAphy1. Hello TypogrAphy2. Hello TypogrAphy3. Hello TypogrAphy4. Hello TypogrAphy5. Hello TypogrAphy6. Hello TypogrAphy7. Hello TypogrAphy8. Hello TypogrAphy9. Hello TypogrAphy10. Hello TypogrAphy11. Hello TypogrAphy12.", null, null, null, true, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.Text.init("Hello TypogrAphy. (change character space)", null, null, null, null, 10, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.Text.init("Hello TypogrAphy. (change word space)", null, null, null, null, null, 10)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.Text.init("Hello TypogrAphy. (mix)", Color.init("FF00FF"), 30, Font.wrap(Font.NamedFont.init("Helvetica", null)), null, 2, 5)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, Alignment.center, null),
        Page.init(Container.wrap(Container.Text.init("Hello TypogrAphy. (mix)", Color.init("FF00FF"), 30, Font.wrap(Font.NamedFont.init("Helvetica", null)), true, 2, 5)), Size.init(@as(f32, 200), @as(f32, 300)), null, null, Alignment.center, null),
    };

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "text", CompressionMode.image, "password", null, EncryptionMode.Revision2, null, &permissions, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/text.pdf");
}
