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
const Default = @import("Default.zig");
const Encode = @import("Encode.zig");
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
font_map: std.StringHashMap(Font.NamedFont),
is_debug: bool,
pdf: Pdf,

pub fn init(allocator: std.mem.Allocator, pdf: Pdf, is_debug: bool) Self {
    return .{
        .allocator = allocator,
        .content_frame_map = std.AutoHashMap(u32, Rect).init(allocator),
        .font_map = std.StringHashMap(Font.NamedFont).init(allocator),
        .is_debug = is_debug,
        .pdf = pdf,
    };
}

pub fn deinit(self: *Self) void {
    self.content_frame_map.deinit();
    self.font_map.deinit();
}

pub fn save(self: *Self, file_name: []const u8) !void {
    const hpdf = c.HPDF_New(errorEandler, null);
    defer c.HPDF_Free(hpdf);

    self.setPdfAttributes(hpdf);

    if (self.pdf.fonts) |fonts| {
        for (fonts) |font| {
            const named_font = self.loadFont(hpdf, font);
            try self.font_map.put(named_font.family, named_font);
        }
    }

    for (self.pdf.pages) |page| {
        switch (page.container) {
            .report => {
                var r_pages = try self.generatePagesFromReport(hpdf, page);
                defer self.allocator.free(r_pages);
                for (r_pages) |r_page| {
                    const hpage = c.HPDF_AddPage(hpdf);

                    try self.renderPage(hpdf, hpage, r_page);
                    try self.renderContainer(hpdf, hpage, r_page.content_frame, r_page.alignment, r_page.container);
                }

                continue;
            },
            else => {},
        }

        const hpage = c.HPDF_AddPage(hpdf);

        try self.renderPage(hpdf, hpage, page);
        try self.renderContainer(hpdf, hpage, page.content_frame, page.alignment, page.container);
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

fn loadFont(self: Self, hpdf: c.HPDF_Doc, font: Font.FontFace) Font.NamedFont {
    _ = self;
    switch (font) {
        .named_font => {
            const named_font = font.named_font;

            return Font.NamedFont.init(named_font.family, named_font.name, named_font.encoding_name);
        },
        .ttc => {
            const ttc = font.ttc;
            const ptr = c.HPDF_LoadTTFontFromFile2(hpdf, ttc.file_path.ptr, ttc.index, if (ttc.embedding) c.HPDF_TRUE else c.HPDF_FALSE);
            const font_name = std.mem.sliceTo(ptr, 0);

            return Font.NamedFont.init(ttc.family, font_name, ttc.encoding_name);
        },
        .ttf => {
            const ttf = font.ttf;
            const ptr = c.HPDF_LoadTTFontFromFile(hpdf, ttf.file_path.ptr, if (ttf.embedding) c.HPDF_TRUE else c.HPDF_FALSE);
            const font_name = std.mem.sliceTo(ptr, 0);

            return Font.NamedFont.init(ttf.family, font_name, ttf.encoding_name);
        },
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
}

fn layoutContainer(self: *Self, hpdf: c.HPDF_Doc, parent_rect: Rect, container: Container.Container) !Size {
    switch (container) {
        .box => {
            const box = container.box;

            if (box.size) |size| {
                return size;
            }

            if (box.child) |child| {
                const child_container = materializeContainer(child);

                const size = parent_rect.size;
                const pad = box.padding orelse Padding.zeroPadding;
                const width = if (box.expanded) (parent_rect.size.width / size.width) * size.width else size.width;
                const height = if (box.expanded) (parent_rect.size.height / size.height) * size.height else size.height;

                var content_frame = parent_rect.offsetLTWH(0, 0, width, height);
                content_frame = content_frame.insets(pad.top, pad.right, pad.bottom, pad.left);

                return try self.layoutContainer(hpdf, content_frame, child_container);
            }

            return Size.zeroSize;
        },
        .positioned_box => {
            return Size.zeroSize;
        },
        .flexible => {
            return Size.zeroSize;
        },
        .column => {
            const column = container.column;

            var flex: u8 = 0;
            var size = Size.zeroSize;

            for (column.children) |child| {
                const child_container = materializeContainer(child);

                var child_size = try self.layoutContainer(hpdf, Rect.zeroRect, child_container);
                size.width = if (size.width < child_size.width) child_size.width else size.width;
                size.height += child_size.height;

                flex += switch (child_container) {
                    .flexible => child_container.flexible.flex,
                    else => 0,
                };
            }

            if (flex > 0) {
                const flex_height = (parent_rect.size.height - size.height) / @intToFloat(f32, flex);

                for (column.children) |child| {
                    const child_container = materializeContainer(child);

                    switch (child_container) {
                        .flexible => {
                            const flexible = child_container.flexible;
                            try self.content_frame_map.put(flexible.id, Rect.init(0, 0, size.width, flex_height * @intToFloat(f32, flexible.flex)));
                        },
                        else => {},
                    }
                }
            }

            return if (flex > 0) Size.init(size.width, parent_rect.size.height) else size;
        },
        .row => {
            const row = container.row;

            var flex: u8 = 0;
            var size = Size.zeroSize;

            for (row.children) |child| {
                const child_container = materializeContainer(child);

                var child_size = try self.layoutContainer(hpdf, Rect.zeroRect, child_container);
                size.width += child_size.width;
                size.height = if (size.height < child_size.height) child_size.height else size.height;

                flex += switch (child_container) {
                    .flexible => child_container.flexible.flex,
                    else => 0,
                };
            }

            if (flex > 0) {
                const flex_width = (parent_rect.size.width - size.width) / @intToFloat(f32, flex);

                for (row.children) |child| {
                    const child_container = materializeContainer(child);

                    switch (child_container) {
                        .flexible => {
                            const flexible = child_container.flexible;
                            try self.content_frame_map.put(flexible.id, Rect.init(0, 0, flex_width * @intToFloat(f32, flexible.flex), size.height));
                        },
                        else => {},
                    }
                }
            }

            return if (flex > 0) Size.init(parent_rect.size.width, size.height) else size;
        },
        .image => {
            const image = container.image;

            if (image.size) |size| {
                return size;
            }

            const extension = std.fs.path.extension(image.path);
            const himage = if (std.mem.eql(u8, extension, ".png")) c.HPDF_LoadPngImageFromFile2(hpdf, image.path.ptr) else c.HPDF_LoadJpegImageFromFile(hpdf, image.path.ptr);
            const imageWidth: f32 = @intToFloat(f32, c.HPDF_Image_GetWidth(himage));
            const imageHeight: f32 = @intToFloat(f32, c.HPDF_Image_GetHeight(himage));

            return Size.init(imageWidth, imageHeight);
        },
        .text => {
            const text = container.text;

            const font: Font.NamedFont = self.font_map.get(text.font_family) orelse @panic("undefined font.");
            const hfont: c.HPDF_Font = c.HPDF_GetFont(hpdf, font.name.ptr, if (font.encoding_name == null) null else font.encoding_name.?.ptr);

            const text_size = text.text_size;
            const word_space = text.word_space;
            const char_space = text.char_space;

            const text_len = @intCast(c_uint, text.content.len);
            const text_width = c.HPDF_Font_TextWidth(hfont, text.content.ptr, text_len);
            const width = ((@intToFloat(f32, text_width.width) / 1000) * text_size) + (word_space * @intToFloat(f32, text_width.numwords - 1)) + (char_space * @intToFloat(f32, text_width.numchars - 1));
            const b_box = c.HPDF_Font_GetBBox(hfont);
            const line_height = ((b_box.top + (b_box.bottom * -1)) / 1000) * text_size;

            return Size.init(width, line_height);
        },
        .report => {
            const report = container.report;

            if (report.header) |header| {
                const header_container = materializeContainer(header);

                var header_size = try self.layoutContainer(hpdf, parent_rect, header_container);
                try self.content_frame_map.put(header_container.getId(), Rect.init(0, 0, header_size.width, header_size.height));
            }

            if (report.footer) |footer| {
                const footer_container = materializeContainer(footer);

                var footer_size = try self.layoutContainer(hpdf, parent_rect, footer_container);
                try self.content_frame_map.put(footer_container.getId(), Rect.init(0, 0, footer_size.width, footer_size.height));
            }

            const body_container = materializeContainer(report.body);

            switch (body_container) {
                .column => {
                    const column = body_container.column;
                    for (column.children) |child| {
                        const child_container = materializeContainer(child);

                        var child_size = try self.layoutContainer(hpdf, parent_rect, child_container);
                        try self.content_frame_map.put(child_container.getId(), Rect.init(0, 0, child_size.width, child_size.height));
                    }
                },
                else => {},
            }

            return Size.init(0, 0);
        },
    }
}

fn renderContainer(self: *Self, hpdf: c.HPDF_Doc, hpage: c.HPDF_Page, rect: Rect, alignment: ?Alignment, container: Container.Container) !void {
    _ = c.HPDF_Page_GSave(hpage);

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
                _ = c.HPDF_Page_TextOut(hpage, content_frame.minX, content_frame.minY, "Box's drawable rect.");
                _ = c.HPDF_Page_EndText(hpage);
            }

            if (box.child) |child| {
                const child_container = materializeContainer(child);

                try self.renderContainer(hpdf, hpage, content_frame, box.alignment, child_container);
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

            if (positioned_box.child) |child| {
                const child_container = materializeContainer(child);

                try self.renderContainer(hpdf, hpage, content_frame, null, child_container);
            }
        },
        .flexible => {
            const flexible = container.flexible;
            const child_container = materializeContainer(flexible.child);

            if (self.content_frame_map.get(flexible.id)) |flexible_rect| {
                const content_frame = rect.offsetLTWH(0, 0, flexible_rect.size.width, flexible_rect.size.height);
                try self.renderContainer(hpdf, hpage, Rect.init(content_frame.origin.x, content_frame.origin.y, content_frame.size.width, content_frame.size.height), null, child_container);
            } else {
                try self.renderContainer(hpdf, hpage, rect, null, child_container);
            }
        },
        .column => {
            const column = container.column;
            var content_frame = rect;

            _ = try self.layoutContainer(hpdf, rect, container);

            if (self.is_debug) {
                try self.drawBorder(hpage, Border.init(Color.init("F00FFF"), Border.Style.dot, 0.5, 0.5, 0.5, 0.5), content_frame);
                _ = c.HPDF_Page_BeginText(hpage);
                _ = c.HPDF_Page_SetRGBFill(hpage, 1.0, 0.0, 0.0);
                _ = c.HPDF_Page_SetTextRenderingMode(hpage, c.HPDF_FILL);
                _ = c.HPDF_Page_TextOut(hpage, content_frame.minX, content_frame.minY, "Columns's drawable rect.");
                _ = c.HPDF_Page_EndText(hpage);
            }

            var children_width: f32 = 0;
            var children_height: f32 = 0;

            for (column.children) |child| {
                const child_container = materializeContainer(child);

                try self.renderContainer(hpdf, hpage, content_frame, null, child_container);
                if (self.content_frame_map.get(child_container.getId())) |child_content_frame| {
                    // std.log.warn("COLUMN CHILD w:{d},h:{d}", .{child_content_frame.size.width, child_content_frame.size.height});
                    // std.log.warn("COLUMN BERFORE x:{d},y:{d}", .{content_frame.origin.x, content_frame.origin.y});
                    content_frame = content_frame.offsetLTWH(0, child_content_frame.height, content_frame.width, content_frame.height - child_content_frame.height);
                    // std.log.warn("COLUMN AFTER x:{d},y:{d}", .{content_frame.origin.x, content_frame.origin.y});

                    children_width = if (children_width < child_content_frame.width) child_content_frame.width else children_width;
                    children_height += child_content_frame.height;
                }
            }

            var wrap_frame = Rect.fromPoints(rect.minX, rect.maxY, rect.minX + children_width, rect.maxY - children_height);
            try self.content_frame_map.put(column.id, wrap_frame);
        },
        .row => {
            const row = container.row;
            var content_frame = rect;

            _ = try self.layoutContainer(hpdf, rect, container);

            if (self.is_debug) {
                try self.drawBorder(hpage, Border.init(Color.init("F00FFF"), Border.Style.dot, 0.5, 0.5, 0.5, 0.5), content_frame);
                _ = c.HPDF_Page_BeginText(hpage);
                _ = c.HPDF_Page_SetRGBFill(hpage, 1.0, 0.0, 0.0);
                _ = c.HPDF_Page_SetTextRenderingMode(hpage, c.HPDF_FILL);
                _ = c.HPDF_Page_TextOut(hpage, content_frame.minX, content_frame.minY, "Rows's drawable rect.");
                _ = c.HPDF_Page_EndText(hpage);
            }

            var children_width: f32 = 0;
            var children_height: f32 = 0;

            for (row.children) |child| {
                const child_container = materializeContainer(child);

                try self.renderContainer(hpdf, hpage, content_frame, null, child_container);
                if (self.content_frame_map.get(child_container.getId())) |child_content_frame| {
                    // std.log.warn("ROW CHILD w:{d},h:{d}", .{child_content_frame.size.width, child_content_frame.size.height});
                    // std.log.warn("ROW BERFORE x:{d},y:{d}", .{content_frame.origin.x, content_frame.origin.y});
                    content_frame = content_frame.offsetLTWH(child_content_frame.width, 0, content_frame.width - child_content_frame.width, content_frame.height);
                    // std.log.warn("ROW AFTER x:{d},y:{d}", .{content_frame.origin.x, content_frame.origin.y});

                    children_width += child_content_frame.width;
                    children_height = if (children_height < child_content_frame.height) child_content_frame.height else children_height;
                }
            }

            var wrap_frame = Rect.fromPoints(rect.minX, rect.maxY, rect.minX + children_width, rect.maxY - children_height);
            try self.content_frame_map.put(row.id, wrap_frame);
        },
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
        .report => {
            const report = container.report;

            _ = try self.layoutContainer(hpdf, rect, container);

            var header_height: f32 = 0;
            var footer_height: f32 = 0;

            if (report.header) |header| {
                const header_container = materializeContainer(header);

                if (self.content_frame_map.get(header_container.getId())) |header_frame| {
                    const content_frame = Rect.init(rect.minX, rect.maxY - header_frame.height, header_frame.width, header_frame.height);
                    try self.renderContainer(hpdf, hpage, content_frame, null, header_container);
                    header_height = content_frame.height;
                }
            }

            if (report.footer) |footer| {
                const footer_container = materializeContainer(footer);

                if (self.content_frame_map.get(footer_container.getId())) |footer_frame| {
                    const content_frame = Rect.init(rect.minX, rect.minY, footer_frame.width, footer_frame.height);
                    try self.renderContainer(hpdf, hpage, content_frame, null, footer_container);
                    footer_height = content_frame.height;
                }
            }

            var body_frame = Rect.init(rect.minX, rect.minY + footer_height, rect.width, rect.height - header_height - footer_height);

            const body_container = materializeContainer(report.body);

            switch (body_container) {
                .column => {
                    const column = body_container.column;
                    for (column.children) |child| {
                        const child_container = materializeContainer(child);

                        try self.renderContainer(hpdf, hpage, body_frame, null, child_container);
                        if (self.content_frame_map.get(child_container.getId())) |child_content_frame| {
                            body_frame = body_frame.offsetLTWH(0, child_content_frame.height, body_frame.width, body_frame.height - child_content_frame.height);
                        }
                    }
                },
                else => {},
            }
        },
    }

    _ = c.HPDF_Page_GRestore(hpage);
}

fn renderBox(self: Self, hpdf: c.HPDF_Doc, hpage: c.HPDF_Page, parent_rect: Rect, alignment: ?Alignment, box: Container.Box) !Rect {
    _ = hpdf;

    const size = box.size orelse parent_rect.size;
    const pad = box.padding orelse Padding.zeroPadding;
    const width = if (box.expanded) (parent_rect.size.width / size.width) * size.width else size.width;
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
    _ = c.HPDF_Page_BeginText(hpage);

    const font: Font.NamedFont = self.font_map.get(text.font_family) orelse @panic("undefined font.");
    const hfont: c.HPDF_Font = c.HPDF_GetFont(hpdf, font.name.ptr, if (font.encoding_name == null) null else font.encoding_name.?.ptr);

    const text_size = text.text_size;
    const word_space = text.word_space;
    const char_space = text.char_space;
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

    switch (text.style) {
        .fill => {
            _ = c.HPDF_Page_SetRGBFill(hpage, 0.0, 0.0, 0.0);
            if (text.fill_color.value) |hex| {
                const rgb = try Rgb.hex(hex);
                const red = @intToFloat(f32, rgb.red) / 255;
                const green = @intToFloat(f32, rgb.green) / 255;
                const blue = @intToFloat(f32, rgb.blue) / 255;
                _ = c.HPDF_Page_SetRGBFill(hpage, red, green, blue);
            }

            _ = c.HPDF_Page_SetTextRenderingMode(hpage, c.HPDF_FILL);
        },
        .stroke => {
            _ = c.HPDF_Page_SetRGBStroke(hpage, 0.0, 0.0, 0.0);
            if (text.stroke_color.value) |hex| {
                const rgb = try Rgb.hex(hex);
                const red = @intToFloat(f32, rgb.red) / 255;
                const green = @intToFloat(f32, rgb.green) / 255;
                const blue = @intToFloat(f32, rgb.blue) / 255;
                _ = c.HPDF_Page_SetRGBStroke(hpage, red, green, blue);
            }

            _ = c.HPDF_Page_SetTextRenderingMode(hpage, c.HPDF_STROKE);
        },
        .fill_and_stroke => {
            _ = c.HPDF_Page_SetRGBFill(hpage, 0.0, 0.0, 0.0);
            if (text.fill_color.value) |hex| {
                const rgb = try Rgb.hex(hex);
                const red = @intToFloat(f32, rgb.red) / 255;
                const green = @intToFloat(f32, rgb.green) / 255;
                const blue = @intToFloat(f32, rgb.blue) / 255;
                _ = c.HPDF_Page_SetRGBFill(hpage, red, green, blue);
            }

            _ = c.HPDF_Page_SetRGBStroke(hpage, 0.0, 0.0, 0.0);
            if (text.stroke_color.value) |hex| {
                const rgb = try Rgb.hex(hex);
                const red = @intToFloat(f32, rgb.red) / 255;
                const green = @intToFloat(f32, rgb.green) / 255;
                const blue = @intToFloat(f32, rgb.blue) / 255;
                _ = c.HPDF_Page_SetRGBStroke(hpage, red, green, blue);
            }

            _ = c.HPDF_Page_SetTextRenderingMode(hpage, c.HPDF_FILL_THEN_STROKE);
        },
    }

    // 指定した領域内にテキストを表示する - HPDF_Page_TextRect
    // 指定した位置にテキストを表示する - HPDF_Page_TextOut
    // ページの現在位置にテキストを表示する - HPDF_Page_ShowText
    if (soft_wrap) {
        // "HPDF_Page_TextRect" は単語の途中で改行されない
        // _ = c.HPDF_Page_TextRect(hpage, content_frame.minX, content_frame.maxY, content_frame.maxX, content_frame.minY, text.content.ptr, c.HPDF_TALIGN_LEFT, null);

        var iter = (try std.unicode.Utf8View.init(text.content)).iterator();

        _ = c.HPDF_Page_MoveTextPos(hpage, content_frame.minX, content_frame.maxY - line_height + descent);
        var x: f32 = 0;
        var w: f32 = 0;
        var buf: [4]u8 = undefined;
        while (iter.nextCodepoint()) |cp| {
            var bytes = try std.unicode.utf8CodepointSequenceLength(cp);

            if (bytes > 1) {
                var utf8 = try self.allocator.alloc(u8, bytes);
                defer self.allocator.free(utf8);
                _ = try std.unicode.utf8Encode(cp, utf8);

                var sjis = try Encode.encodeSjis(self.allocator, utf8);
                defer self.allocator.free(sjis);

                x = c.HPDF_Page_GetCurrentTextPos(hpage).x;
                w = emToPoint(@intToFloat(f32, c.HPDF_Font_TextWidth(hfont, sjis.ptr, 1).width), text_size);
                if (x + w > content_frame.maxX) {
                    _ = c.HPDF_Page_MoveToNextLine(hpage);
                }
                _ = c.HPDF_Page_ShowText(hpage, sjis.ptr);

                continue;
            }

            var s = try std.fmt.bufPrintZ(&buf, "{u}", .{cp});
            x = c.HPDF_Page_GetCurrentTextPos(hpage).x;
            w = emToPoint(@intToFloat(f32, c.HPDF_Font_TextWidth(hfont, s.ptr, 1).width), text_size);
            if (x + w > content_frame.maxX) {
                _ = c.HPDF_Page_MoveToNextLine(hpage);
            }
            _ = c.HPDF_Page_ShowText(hpage, s.ptr);
        }
    } else {
        const sjis = try Encode.encodeSjis(self.allocator, text.content);
        defer self.allocator.free(sjis);

        _ = c.HPDF_Page_TextOut(hpage, content_frame.minX, content_frame.minY + descent, sjis.ptr);
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

fn generatePagesFromReport(self: *Self, hpdf: c.HPDF_Doc, orig_page: Page) ![]Page {
    var init_size: usize = 10;
    var used_size: usize = 0;

    var pages: []Page = try self.allocator.alloc(Page, init_size);

    _ = try self.layoutContainer(hpdf, orig_page.frame, orig_page.container);

    const report = orig_page.container.report;

    var has_header = false;
    var has_footer = false;
    var header_height: f32 = 0;
    var footer_height: f32 = 0;

    if (report.header) |header| {
        const header_container = materializeContainer(header);

        if (self.content_frame_map.get(header_container.getId())) |header_frame| {
            has_header = true;
            header_height = header_frame.height;
        }
    }

    if (report.footer) |footer| {
        const footer_container = materializeContainer(footer);

        if (self.content_frame_map.get(footer_container.getId())) |footer_frame| {
            has_footer = true;
            footer_height = footer_frame.height;
        }
    }

    const rect = orig_page.frame;
    var body_frame = Rect.init(rect.minX, rect.minY + footer_height, rect.width, rect.height - header_height - footer_height);
    _ = body_frame;

    const body_container = materializeContainer(report.body);

    switch (body_container) {
        .column => {
            // pages[0] = Page.init(Container.wrap(report), orig_page.frame.size, orig_page.background_color, orig_page.padding, orig_page.alignment, orig_page.border);
            // used_size += 1;
        },
        else => {},
    }

    return try self.allocator.realloc(pages, used_size);
}

fn materializeContainer(any: *anyopaque) Container.Container {
    const pointer: *Container.Container = @ptrCast(*Container.Container, @alignCast(@alignOf(Container.Container), any));

    return pointer.*;
}

fn emToPoint(em: f32, text_size: f32) f32 {
    return (em / 1000) * text_size;
}

fn errorEandler(error_no: c.HPDF_STATUS, detail_no: c.HPDF_STATUS, user_data: ?*anyopaque) callconv(.C) void {
    _ = user_data;
    std.log.err("libHaru ERROR: error_no={}, detail_no={}", .{ error_no, detail_no });
}

test "permission" {
    const permissions = [_]PermissionName{
        PermissionName.read,
    };

    var pages = [_]Page{
        Page.init(Container.wrap(Container.Box.init(false, null, null, null, null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
    };

    var fonts = [_]Font.FontFace{Font.wrap(Font.NamedFont.init("Helvetica", "Helvetica", null))};

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "permission", CompressionMode.none, "password", null, EncryptionMode.Revision2, null, &permissions, &fonts, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/permission.pdf");
}

test "page" {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.edit_all,
    };

    const text_color = Color.init(Default.text_color);
    const char_space_0 = 0;
    const word_space_0 = 0;

    var pages = [_]Page{
        Page.init(Container.wrap(Container.Text.init("Background color #EFEFEF", text_color, null, .fill, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 842)), Color.init("EFEFEF"), null, null, null),
        Page.init(Container.wrap(Container.Text.init("Padding color (10, 10, 10, 10)", text_color, null, .fill, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Text.init("Alignment top x left", text_color, null, .fill, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.topLeft, null),
        Page.init(Container.wrap(Container.Text.init("Alignment top x center", text_color, null, .fill, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.topCenter, null),
        Page.init(Container.wrap(Container.Text.init("Alignment top x right", text_color, null, .fill, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.topRight, null),
        Page.init(Container.wrap(Container.Text.init("Alignment center x left", text_color, null, .fill, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.centerLeft, null),
        Page.init(Container.wrap(Container.Text.init("Alignment center", text_color, null, .fill, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.center, null),
        Page.init(Container.wrap(Container.Text.init("Alignment center x right", text_color, null, .fill, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.centerRight, null),
        Page.init(Container.wrap(Container.Text.init("Alignment bottom x left", text_color, null, .fill, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.bottomLeft, null),
        Page.init(Container.wrap(Container.Text.init("Alignment bottom x center", text_color, null, .fill, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.bottomCenter, null),
        Page.init(Container.wrap(Container.Text.init("Alignment bottom x right", text_color, null, .fill, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.bottomRight, null),
        Page.init(Container.wrap(Container.Text.init("Border", text_color, null, .fill, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, Border.init(Color.init("0FF0FF"), Border.Style.dot, 5, 5, 5, 5)),
        Page.init(Container.wrap(Container.Text.init("All page properties", text_color, null, .fill, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(50, 50, 50, 50), Alignment.topRight, Border.init(Color.init("FFF00F"), Border.Style.dot, 5, 5, 5, 5)),
    };

    var fonts = [_]Font.FontFace{
        Font.wrap(Font.NamedFont.init("Default", "MS-Gothic", "90ms-RKSJ-H")),
        Font.wrap(Font.NamedFont.init("Helvetica", "Helvetica", null)),
        Font.wrap(Font.Ttf.init("MPLUS1p-Thin", "src/fonts/MPLUS1p-Thin.ttf", true, null)),
    };

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "page", CompressionMode.none, "password", null, EncryptionMode.Revision2, null, &permissions, &fonts, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/page.pdf");
}

test "box" {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.edit_all,
    };

    const char_space_0 = 0;
    const word_space_0 = 0;
    const text_size_30 = 30;

    var child = Container.wrap(Container.Box.init(false, null, Color.init("DEDEDE"), null, null, null, Size.init(200, 200)));
    const opaque_child: *anyopaque = &child;

    var text = Container.wrap(Container.Text.init("Hello World :)", Color.init("000FFF"), null, .fill, text_size_30, "Default", false, char_space_0, word_space_0));
    const opaque_text: *anyopaque = &text;

    var text2 = Container.wrap(Container.Text.init("Hello World :)", Color.init("000FFF"), null, .fill, Default.text_size, "Default", false, char_space_0, word_space_0));
    const opaque_text2: *anyopaque = &text2;

    var child2 = Container.wrap(Container.Box.init(false, null, Color.init("DEDEDE"), null, opaque_text2, Padding.init(10, 10, 10, 10), Size.init(200, 200)));
    const opaque_child2: *anyopaque = &child2;

    var pages = [_]Page{
        Page.init(Container.wrap(Container.Box.init(false, null, null, null, null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Box.init(false, Alignment.center, null, null, null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Box.init(false, null, Color.init("EFEFEF"), null, null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Box.init(false, null, null, Border.init(Color.init("0FF0FF"), Border.Style.dot, 1, 1, 1, 1), null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Box.init(false, null, null, null, null, Padding.init(10, 10, 10, 10), null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Box.init(false, null, null, null, null, null, Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Box.init(false, Alignment.center, Color.init("EFEFEF"), Border.init(Color.init("0FF0FF"), Border.Style.solid, 5, 5, 5, 5), null, Padding.init(10, 10, 10, 10), Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), Alignment.center, null),
        Page.init(Container.wrap(Container.Box.init(false, null, null, null, null, null, Size.init(600, 900))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.Box.init(true, null, null, null, null, null, Size.init(600, 900))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.Box.init(false, Alignment.bottomRight, Color.init("EFEFEF"), null, opaque_child, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Box.init(false, Alignment.bottomLeft, Color.init("EFEFEF"), null, opaque_child2, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Box.init(false, Alignment.center, null, null, opaque_text, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
    };

    var fonts = [_]Font.FontFace{ Font.wrap(Font.NamedFont.init("Default", "MS-Gothic", "90ms-RKSJ-H")), Font.wrap(Font.NamedFont.init("Helvetica", "Helvetica", null)) };

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "box", CompressionMode.none, "password", null, EncryptionMode.Revision2, null, &permissions, &fonts, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/box.pdf");
}

test "positioned_box" {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.edit_all,
    };

    var child = Container.wrap(Container.PositionedBox.init(null, null, null, 50, 50, Size.init(100, 100)));
    const opaque_child: *anyopaque = &child;

    var pages = [_]Page{
        Page.init(Container.wrap(Container.PositionedBox.init(null, 50, null, null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(null, null, 50, null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(null, null, null, 50, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(null, null, null, null, 50, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(null, null, null, null, null, Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(null, 50, 50, 50, 50, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(null, 50, 50, null, null, Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(null, null, null, 50, 50, Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(null, null, 50, 50, null, Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(opaque_child, 50, 50, null, null, Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
    };

    var fonts = [_]Font.FontFace{Font.wrap(Font.NamedFont.init("Helvetica", "Helvetica", null))};

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "positioned_box", CompressionMode.text, "password", null, EncryptionMode.Revision2, null, &permissions, &fonts, &pages);
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

    var fonts = [_]Font.FontFace{Font.wrap(Font.NamedFont.init("Helvetica", "Helvetica", null))};

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "image", CompressionMode.image, "password", null, EncryptionMode.Revision2, null, &permissions, &fonts, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/image.pdf");
}

test "text" {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.edit_all,
    };

    const text_color = Color.init(Default.text_color);
    const text_size_20 = 20;
    const text_size_30 = 30;
    const char_space_0 = 0;
    const char_space_2 = 2;
    const char_space_10 = 10;
    const word_space_0 = 0;
    const word_space_5 = 5;
    const word_space_10 = 10;

    const text1 = Container.Text.init("Hello TypogrAphy. (default)", text_color, null, .fill, Default.text_size, "Default", false, char_space_0, word_space_0);

    const text2 = Container.Text.init("Hello TypogrAphy. (change color)", Color.init("FF00FF"), null, .fill, Default.text_size, "Default", false, char_space_0, word_space_0);

    const text3 = Container.Text.init("Hello TypogrAphy. (change size)", text_color, null, .fill, text_size_20, "Default", false, char_space_0, word_space_0);

    const text4 = Container.Text.init("Hello TypogrAphy. (change font face to helvetica)", text_color, null, .fill, Default.text_size, "Helvetica", false, char_space_0, word_space_0);

    const text5 = Container.Text.init("Hello TypogrAphy. (change font face to mplus1p)", text_color, null, .fill, Default.text_size, "MPLUS1p-Thin", false, char_space_0, word_space_0);

    const text6 = Container.Text.init("Hello TypogrAphy1. Hello TypogrAphy2. Hello TypogrAphy3. Hello TypogrAphy4. Hello TypogrAphy5. Hello TypogrAphy6. Hello TypogrAphy7. Hello TypogrAphy8. Hello TypogrAphy9. Hello TypogrAphy10. Hello TypogrAphy11. Hello TypogrAphy12.", text_color, null, .fill, Default.text_size, "Default", true, char_space_0, word_space_0);

    const text7 = Container.Text.init("Hello TypogrAphy. (change character space)", text_color, null, .fill, Default.text_size, "Default", false, char_space_10, word_space_0);

    const text8 = Container.Text.init("Hello TypogrAphy. (change word space)", text_color, null, .fill, Default.text_size, "Default", false, char_space_0, word_space_10);

    const text9 = Container.Text.init("Hello TypogrAphy. (mix)", Color.init("60FFF0"), Color.init("000000"), .fill_and_stroke, text_size_30, "Helvetica", false, char_space_2, word_space_5);

    const text10 = Container.Text.init("Hello TypogrAphy. (mix)", Color.init("FF00FF"), null, .stroke, text_size_30, "Helvetica", true, char_space_2, word_space_5);

    const text11 = Container.Text.init("こんにちは　タイポグラフィ。(デフォルト)", text_color, null, .fill, text_size_30, "MPLUS1p-Thin", false, char_space_2, word_space_5);

    const text12 = Container.Text.init("こんにちは　タイポグラフィ。(デフォルト)", text_color, null, .fill, text_size_30, "MPLUS1p-Thin", true, char_space_2, word_space_5);

    var pages = [_]Page{
        Page.init(Container.wrap(text1), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(text2), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(text3), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(text4), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(text5), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(text6), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(text7), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(text8), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(text9), Size.init(@as(f32, 595), @as(f32, 842)), null, null, Alignment.center, null),
        Page.init(Container.wrap(text10), Size.init(@as(f32, 200), @as(f32, 300)), null, null, Alignment.center, null),
        Page.init(Container.wrap(text11), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(text12), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
    };

    var fonts = [_]Font.FontFace{
        Font.wrap(Font.NamedFont.init("Default", "MS-Gothic", "90ms-RKSJ-H")),
        Font.wrap(Font.NamedFont.init("Helvetica", "Helvetica", null)),
        Font.wrap(Font.Ttf.init("MPLUS1p-Thin", "src/fonts/MPLUS1p-Thin.ttf", true, "90msp-RKSJ-H")),
    };

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "text", CompressionMode.image, "password", null, EncryptionMode.Revision2, null, &permissions, &fonts, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/text.pdf");
}

test "column" {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.edit_all,
    };

    var box1 = Container.wrap(Container.Box.init(false, null, Color.init("00F0F0"), null, null, null, Size.init(100, 50)));
    const opaque_box1: *anyopaque = &box1;

    var box2 = Container.wrap(Container.Box.init(false, null, Color.init("F00FFF"), null, null, null, Size.init(100, 50)));
    const opaque_box2: *anyopaque = &box2;

    var children = [_]*anyopaque{
        opaque_box1,
        opaque_box2,
    };

    var pages = [_]Page{
        Page.init(Container.wrap(Container.Column.init(&children, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
    };

    var fonts = [_]Font.FontFace{Font.wrap(Font.NamedFont.init("Helvetica", "Helvetica", null))};

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "column", CompressionMode.none, "password", null, EncryptionMode.Revision2, null, &permissions, &fonts, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/column.pdf");
}

test "row" {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.edit_all,
    };

    var box1 = Container.wrap(Container.Box.init(false, null, Color.init("00F0F0"), null, null, null, Size.init(100, 50)));
    const opaque_box1: *anyopaque = &box1;

    var box2 = Container.wrap(Container.Box.init(false, null, Color.init("F00FFF"), null, null, null, Size.init(100, 50)));
    const opaque_box2: *anyopaque = &box2;

    var children = [_]*anyopaque{
        opaque_box1,
        opaque_box2,
    };

    var pages = [_]Page{
        Page.init(Container.wrap(Container.Row.init(&children, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
    };

    var fonts = [_]Font.FontFace{Font.wrap(Font.NamedFont.init("Helvetica", "Helvetica", null))};

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "row", CompressionMode.none, "password", null, EncryptionMode.Revision2, null, &permissions, &fonts, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/row.pdf");
}

test "flexible" {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.edit_all,
    };

    var box0 = Container.wrap(Container.Box.init(false, null, Color.init("00F0F0"), null, null, null, Size.init(100, 50)));
    const opaque_box0: *anyopaque = &box0;

    // child1
    var text1 = Container.wrap(Container.Text.init("Hello TypogrAphy. (flex1)", Color.init(Default.text_color), null, .fill, Default.text_size, "Default", true, 0, 0));
    const opaque_text1: *anyopaque = &text1;

    var box1 = Container.wrap(Container.Box.init(true, null, null, Border.init(Color.init("0FF0FF"), Border.Style.dot, 1, 1, 1, 1), opaque_text1, null, null));
    const opaque_box1: *anyopaque = &box1;

    var flexible1 = Container.wrap(Container.Flexible.init(opaque_box1, 1));
    const opaque_flexible1: *anyopaque = &flexible1;

    // child2
    var text2 = Container.wrap(Container.Text.init("Hello TypogrAphy. (flex2)", Color.init(Default.text_color), null, .fill, Default.text_size, "Default", false, 0, 0));
    const opaque_text2: *anyopaque = &text2;

    var box2 = Container.wrap(Container.Box.init(true, null, null, Border.init(Color.init("0FF0FF"), Border.Style.dot, 1, 1, 1, 1), opaque_text2, null, null));
    const opaque_box2: *anyopaque = &box2;

    var flexible2 = Container.wrap(Container.Flexible.init(opaque_box2, 2));
    const opaque_flexible2: *anyopaque = &flexible2;

    // child3
    var text3 = Container.wrap(Container.Text.init("Hello TypogrAphy. (flex3)", Color.init(Default.text_color), null, .fill, Default.text_size, "Default", false, 0, 0));
    const opaque_text3: *anyopaque = &text3;

    var box3 = Container.wrap(Container.Box.init(true, null, null, Border.init(Color.init("0FF0FF"), Border.Style.dot, 1, 1, 1, 1), opaque_text3, null, null));
    const opaque_box3: *anyopaque = &box3;

    var flexible3 = Container.wrap(Container.Flexible.init(opaque_box3, 3));
    const opaque_flexible3: *anyopaque = &flexible3;

    var children = [_]*anyopaque{
        opaque_box0,
        opaque_flexible1,
        opaque_flexible2,
        opaque_flexible3,
    };

    var pages = [_]Page{
        Page.init(Container.wrap(Container.Row.init(&children, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Column.init(&children, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
    };

    var fonts = [_]Font.FontFace{Font.wrap(Font.NamedFont.init("Default", "Helvetica", null))};

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "column", CompressionMode.none, "password", null, EncryptionMode.Revision2, null, &permissions, &fonts, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/flexible.pdf");
}

test "row_column" {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.edit_all,
    };

    const char_space_0 = 0;
    const word_space_0 = 0;

    var text1 = Container.wrap(Container.Text.init("Box1 Box1 Box1 Box1 Box1 Box1", Color.init("000FFF"), null, .fill, Default.text_size, "Default", true, char_space_0, word_space_0));
    const opaque_text1: *anyopaque = &text1;

    var box1 = Container.wrap(Container.Box.init(false, null, Color.init("00F0F0"), null, opaque_text1, null, Size.init(100, 50)));
    const opaque_box1: *anyopaque = &box1;

    var text2 = Container.wrap(Container.Text.init("Box2", Color.init("000FFF"), null, .fill, Default.text_size, "Default", false, char_space_0, word_space_0));
    const opaque_text2: *anyopaque = &text2;

    var box2 = Container.wrap(Container.Box.init(false, null, Color.init("F00FFF"), null, opaque_text2, null, Size.init(100, 50)));
    const opaque_box2: *anyopaque = &box2;

    var boxes1 = [_]*anyopaque{
        opaque_box1,
        opaque_box2,
    };

    var text3 = Container.wrap(Container.Text.init("Box3", Color.init("000FFF"), null, .fill, Default.text_size, "Default", false, char_space_0, word_space_0));
    const opaque_text3: *anyopaque = &text3;

    var box3 = Container.wrap(Container.Box.init(false, null, Color.init("F0F0FF"), null, opaque_text3, null, Size.init(100, 50)));
    const opaque_box3: *anyopaque = &box3;

    var text4 = Container.wrap(Container.Text.init("Box4", Color.init("000FFF"), null, .fill, Default.text_size, "Default", false, char_space_0, word_space_0));
    const opaque_text4: *anyopaque = &text4;

    var box4 = Container.wrap(Container.Box.init(false, null, Color.init("F0FFF0"), null, opaque_text4, null, Size.init(100, 50)));
    const opaque_box4: *anyopaque = &box4;

    var boxes2 = [_]*anyopaque{
        opaque_box3,
        opaque_box4,
    };

    var column1 = Container.wrap(Container.Column.init(&boxes1, null));
    const opaque_column1: *anyopaque = &column1;

    var column2 = Container.wrap(Container.Column.init(&boxes2, null));
    const opaque_column2: *anyopaque = &column2;

    var children = [_]*anyopaque{
        opaque_column1,
        opaque_column2,
    };

    var pages = [_]Page{
        Page.init(Container.wrap(Container.Row.init(&children, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
    };

    var fonts = [_]Font.FontFace{ Font.wrap(Font.NamedFont.init("Default", "MS-Gothic", "90ms-RKSJ-H")), Font.wrap(Font.NamedFont.init("Helvetica", "Helvetica", null)) };

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "row_column", CompressionMode.none, "password", null, EncryptionMode.Revision2, null, &permissions, &fonts, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/row_column.pdf");
}

test "report" {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.edit_all,
    };

    var header_text = Container.wrap(Container.Text.init("HEADER", Color.init("000FFF"), null, .fill, Default.text_size, "Default", true, 0, 0));
    const opaque_header_text: *anyopaque = &header_text;

    var header = Container.wrap(Container.Box.init(false, null, Color.init("FFF0F0"), null, opaque_header_text, null, Size.init(595 - 10 - 10, 100)));
    const opaque_header: *anyopaque = &header;

    var box1 = Container.wrap(Container.Box.init(false, null, Color.init("00F0F0"), null, null, null, Size.init(595 - 10 - 10, 50)));
    const opaque_box1: *anyopaque = &box1;

    var box2 = Container.wrap(Container.Box.init(false, null, Color.init("F00FFF"), null, null, null, Size.init(595 - 10 - 10, 50)));
    const opaque_box2: *anyopaque = &box2;

    var box3 = Container.wrap(Container.Box.init(false, null, Color.init("00F0F0"), null, null, null, Size.init(595 - 10 - 10, 50)));
    const opaque_box3: *anyopaque = &box3;

    var box4 = Container.wrap(Container.Box.init(false, null, Color.init("F00FFF"), null, null, null, Size.init(595 - 10 - 10, 50)));
    const opaque_box4: *anyopaque = &box4;

    var box5 = Container.wrap(Container.Box.init(false, null, Color.init("00F0F0"), null, null, null, Size.init(595 - 10 - 10, 50)));
    const opaque_box5: *anyopaque = &box5;

    var box6 = Container.wrap(Container.Box.init(false, null, Color.init("F00FFF"), null, null, null, Size.init(595 - 10 - 10, 50)));
    const opaque_box6: *anyopaque = &box6;

    var box7 = Container.wrap(Container.Box.init(false, null, Color.init("00F0F0"), null, null, null, Size.init(595 - 10 - 10, 50)));
    const opaque_box7: *anyopaque = &box7;

    var box8 = Container.wrap(Container.Box.init(false, null, Color.init("F00FFF"), null, null, null, Size.init(595 - 10 - 10, 50)));
    const opaque_box8: *anyopaque = &box8;

    var box9 = Container.wrap(Container.Box.init(false, null, Color.init("00F0F0"), null, null, null, Size.init(595 - 10 - 10, 50)));
    const opaque_box9: *anyopaque = &box9;

    var box10 = Container.wrap(Container.Box.init(false, null, Color.init("F00FFF"), null, null, null, Size.init(595 - 10 - 10, 50)));
    const opaque_box10: *anyopaque = &box10;

    var box11 = Container.wrap(Container.Box.init(false, null, Color.init("00F0F0"), null, null, null, Size.init(595 - 10 - 10, 50)));
    const opaque_box11: *anyopaque = &box11;

    var box12 = Container.wrap(Container.Box.init(false, null, Color.init("F00FFF"), null, null, null, Size.init(595 - 10 - 10, 50)));
    const opaque_box12: *anyopaque = &box12;

    var box13 = Container.wrap(Container.Box.init(false, null, Color.init("00F0F0"), null, null, null, Size.init(595 - 10 - 10, 50)));
    const opaque_box13: *anyopaque = &box13;

    var box14 = Container.wrap(Container.Box.init(false, null, Color.init("F00FFF"), null, null, null, Size.init(595 - 10 - 10, 50)));
    const opaque_box14: *anyopaque = &box14;

    var box15 = Container.wrap(Container.Box.init(false, null, Color.init("00F0F0"), null, null, null, Size.init(595 - 10 - 10, 50)));
    const opaque_box15: *anyopaque = &box15;

    var box16 = Container.wrap(Container.Box.init(false, null, Color.init("F00FFF"), null, null, null, Size.init(595 - 10 - 10, 50)));
    const opaque_box16: *anyopaque = &box16;

    var boxes = [_]*anyopaque{
        opaque_box1,
        opaque_box2,
        opaque_box3,
        opaque_box4,
        opaque_box5,
        opaque_box6,
        opaque_box7,
        opaque_box8,
        opaque_box9,
        opaque_box10,
        opaque_box11,
        opaque_box12,
        opaque_box13,
        opaque_box14,
        opaque_box15,
        opaque_box16,
    };

    var column = Container.wrap(Container.Column.init(&boxes, null));
    const opaque_column: *anyopaque = &column;

    var footer_text = Container.wrap(Container.Text.init("FOOTER", Color.init("000FFF"), null, .fill, Default.text_size, "Default", true, 0, 0));
    const opaque_footer_text: *anyopaque = &footer_text;

    var footer = Container.wrap(Container.Box.init(false, null, Color.init("FFF0F0"), null, opaque_footer_text, null, Size.init(595 - 10 - 10, 50)));
    const opaque_footer: *anyopaque = &footer;

    var report = Container.Report.init(
        opaque_header,
        false,
        opaque_column,
        opaque_footer,
        false,
    );

    var pages = [_]Page{
        Page.init(Container.wrap(report), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
    };

    var fonts = [_]Font.FontFace{Font.wrap(Font.NamedFont.init("Default", "Helvetica", null))};

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "report", CompressionMode.none, "password", null, EncryptionMode.Revision2, null, &permissions, &fonts, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/report.pdf");
}
