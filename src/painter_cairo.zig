const render = @import("render.zig");
const config = @import("config.zig").config;
pub const c = @import("x11.zig").c;

pub const Painter = struct {
    surface: *c.cairo_surface_t,
    cr: *c.cairo_t,
    colors: render.RGBColorSet,

    pub fn init(display: *c.Display, screen: c_int, window: c.Window, width: i32, height: i32) !Painter {
        const visual = c.XDefaultVisual(display, screen);
        const surface = c.cairo_xlib_surface_create(display, window, visual, width, height) orelse {
            return error.CairoSurfaceCreateFailed;
        };
        if (c.cairo_surface_status(surface) != c.CAIRO_STATUS_SUCCESS) {
            return error.CairoSurfaceCreateFailed;
        }
        errdefer c.cairo_surface_destroy(surface);

        const cr = c.cairo_create(surface) orelse {
            return error.CairoCreateFailed;
        };
        if (c.cairo_status(cr) != c.CAIRO_STATUS_SUCCESS) {
            return error.CairoCreateFailed;
        }
        errdefer c.cairo_destroy(cr);

        c.cairo_set_antialias(cr, c.CAIRO_ANTIALIAS_NONE);
        c.cairo_set_line_width(cr, 1.0);

        return .{
            .surface = surface,
            .cr = cr,
            .colors = config.rgbColorSet(),
        };
    }

    pub fn deinit(self: *Painter) void {
        c.cairo_destroy(self.cr);
        c.cairo_surface_destroy(self.surface);
    }

    pub fn resize(self: *Painter, width: i32, height: i32) void {
        c.cairo_xlib_surface_set_size(self.surface, width, height);
    }

    fn setSource(self: *Painter, color: render.Color) void {
        const rgb = self.colors.get(color);
        const r = @as(f64, @floatFromInt((rgb >> 16) & 0xff)) / 255.0;
        const g = @as(f64, @floatFromInt((rgb >> 8) & 0xff)) / 255.0;
        const b = @as(f64, @floatFromInt(rgb & 0xff)) / 255.0;
        c.cairo_set_source_rgb(self.cr, r, g, b);
    }

    pub fn drawRect(self: *Painter, x: i32, y: i32, w: i32, h: i32, color: render.Color) void {
        self.setSource(color);
        c.cairo_new_path(self.cr);
        c.cairo_rectangle(
            self.cr,
            @as(f64, @floatFromInt(x)) + 0.5,
            @as(f64, @floatFromInt(y)) + 0.5,
            @as(f64, @floatFromInt(w)) - 1.0,
            @as(f64, @floatFromInt(h)) - 1.0,
        );
        c.cairo_stroke(self.cr);
    }

    pub fn drawFillRect(self: *Painter, x: i32, y: i32, w: i32, h: i32, color: render.Color) void {
        self.setSource(color);
        c.cairo_rectangle(
            self.cr,
            @as(f64, @floatFromInt(x)),
            @as(f64, @floatFromInt(y)),
            @as(f64, @floatFromInt(w)),
            @as(f64, @floatFromInt(h)),
        );
        c.cairo_fill(self.cr);
    }
};
