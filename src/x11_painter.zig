const zix11 = @import("zix11");
const x = zix11.x;
const render = @import("render.zig");
const config = @import("config.zig").config;

pub const X11Painter = struct {
    conn: *zix11.Connection,
    window: x.Window,
    gc: x.Gcontext,
    colors: render.RGBColorSet,

    pub fn init(conn: *zix11.Connection, window: x.Window, gc: x.Gcontext) X11Painter {
        return .{
            .conn = conn,
            .window = window,
            .gc = gc,
            .colors = config.rgbColorSet(),
        };
    }

    pub fn drawRect(self: *X11Painter, x0: i32, y0: i32, w: i32, h: i32, color: render.Color) !void {
        if (w <= 0 or h <= 0) return;
        try self.setForeground(color);
        const rects = [_]x.RECTANGLE{
            .{ .x = @intCast(x0), .y = @intCast(y0), .width = @intCast(w), .height = 1 },
            .{ .x = @intCast(x0), .y = @intCast(y0 + h - 1), .width = @intCast(w), .height = 1 },
            .{ .x = @intCast(x0), .y = @intCast(y0), .width = 1, .height = @intCast(h) },
            .{ .x = @intCast(x0 + w - 1), .y = @intCast(y0), .width = 1, .height = @intCast(h) },
        };
        try self.conn.request(x.PolyFillRectangle, .{
            .drawable = .{ .window = self.window },
            .gc = self.gc,
            .rectangles = &rects,
        });
    }

    pub fn drawFillRect(self: *X11Painter, x0: i32, y0: i32, w: i32, h: i32, color: render.Color) !void {
        if (w <= 0 or h <= 0) return;
        try self.setForeground(color);
        const rects = [_]x.RECTANGLE{.{
            .x = @intCast(x0),
            .y = @intCast(y0),
            .width = @intCast(w),
            .height = @intCast(h),
        }};
        try self.conn.request(x.PolyFillRectangle, .{
            .drawable = .{ .window = self.window },
            .gc = self.gc,
            .rectangles = &rects,
        });
    }

    fn setForeground(self: *X11Painter, color: render.Color) !void {
        try self.conn.request(x.ChangeGC, .{
            .gc = self.gc,
            .value_list = .{
                .foreground = self.colors.get(color),
            },
        });
    }
};
