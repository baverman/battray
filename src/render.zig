const std = @import("std");
const c = @import("x11.zig").c;

pub const Renderer = struct {
    display: *c.Display,
    screen: c_int,
    visual: *c.Visual,
    colormap: c.Colormap,
    draw: *c.XftDraw,
    color: c.XftColor,
    font_large: *c.XftFont,
    font_small: *c.XftFont,
    width: u16,
    height: u16,

    pub fn init(display: *c.Display, screen: c_int, window: c.Window, width: u16, height: u16) !Renderer {
        const visual = c.XDefaultVisual(display, screen);
        const colormap = c.XDefaultColormap(display, screen);

        const draw = c.XftDrawCreate(display, window, visual, colormap) orelse return error.XftDrawCreateFailed;
        errdefer c.XftDrawDestroy(draw);

        const font_large = c.XftFontOpenName(display, screen, "DejaVu Sans-13") orelse return error.XftFontOpenFailed;
        errdefer c.XftFontClose(display, font_large);

        const font_small = c.XftFontOpenName(display, screen, "DejaVu Sans-9") orelse return error.XftFontOpenFailed;
        errdefer c.XftFontClose(display, font_small);

        var color: c.XftColor = undefined;
        if (c.XftColorAllocName(display, visual, colormap, "white", &color) == 0) {
            return error.XftColorAllocFailed;
        }

        return .{
            .display = display,
            .screen = screen,
            .visual = visual,
            .colormap = colormap,
            .draw = draw,
            .color = color,
            .font_large = font_large,
            .font_small = font_small,
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: *Renderer) void {
        c.XftColorFree(self.display, self.visual, self.colormap, &self.color);
        c.XftFontClose(self.display, self.font_small);
        c.XftFontClose(self.display, self.font_large);
        c.XftDrawDestroy(self.draw);
    }

    pub fn resize(self: *Renderer, window: c.Window, width: u16, height: u16) void {
        self.width = width;
        self.height = height;
        c.XftDrawChange(self.draw, window);
    }

    pub fn drawText(self: *Renderer, window: c.Window, text: []const u8) void {
        const font = if (text.len < 3) self.font_large else self.font_small;

        _ = c.XClearWindow(self.display, window);

        var extents: c.XGlyphInfo = undefined;
        c.XftTextExtentsUtf8(
            self.display,
            font,
            text.ptr,
            @intCast(text.len),
            &extents,
        );

        const width_i32: i32 = self.width;
        const height_i32: i32 = self.height;
        const text_width: i32 = @intCast(extents.xOff);
        const x: c_int = @intCast(@divTrunc(width_i32 - text_width, 2));
        const y: c_int = @intCast(@divTrunc(height_i32 + font.*.ascent - font.*.descent, 2));

        c.XftDrawStringUtf8(
            self.draw,
            &self.color,
            font,
            x,
            y,
            text.ptr,
            @intCast(text.len),
        );

        _ = c.XFlush(self.display);
    }
};
