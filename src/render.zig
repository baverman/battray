const c = @import("x11.zig").c;

pub const Renderer = struct {
    display: *c.Display,
    colormap: c.Colormap,
    gc: c.GC,
    border_pixel: c_ulong,
    good_pixel: c_ulong,
    warn_pixel: c_ulong,
    crit_pixel: c_ulong,
    width: u16,
    height: u16,

    pub fn init(display: *c.Display, screen: c_int, window: c.Window, width: u16, height: u16) !Renderer {
        const colormap = c.XDefaultColormap(display, screen);
        const gc = c.XCreateGC(display, window, 0, null) orelse return error.XCreateGCFailed;
        errdefer _ = c.XFreeGC(display, gc);

        return .{
            .display = display,
            .colormap = colormap,
            .gc = gc,
            .border_pixel = try allocColor(display, colormap, "#aaaaaa"),
            .good_pixel = try allocColor(display, colormap, "#5fd35f"),
            .warn_pixel = try allocColor(display, colormap, "#e0b43b"),
            .crit_pixel = try allocColor(display, colormap, "#d9534f"),
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: *Renderer) void {
        _ = c.XFreeGC(self.display, self.gc);
    }

    pub fn resize(self: *Renderer, _: c.Window, width: u16, height: u16) void {
        self.width = width;
        self.height = height;
    }

    pub fn drawBatteryLevel(self: *Renderer, window: c.Window, percent: u8) void {
        _ = c.XClearWindow(self.display, window);
        drawBattery(self, window, percent);
        _ = c.XFlush(self.display);
    }
};

fn allocColor(display: *c.Display, colormap: c.Colormap, name: [:0]const u8) !c_ulong {
    var screen_def: c.XColor = undefined;
    var exact_def: c.XColor = undefined;
    if (c.XAllocNamedColor(display, colormap, name.ptr, &screen_def, &exact_def) == 0) {
        return error.XAllocColorFailed;
    }
    return screen_def.pixel;
}

fn drawBattery(self: *Renderer, window: c.Window, percent: u8) void {
    const width_i32: i32 = self.width;
    const height_i32: i32 = self.height;

    const body_w: i32 = 16;
    const body_h: i32 = 10;
    const nub_w: i32 = 2;
    const nub_h: i32 = 4;

    const body_x: i32 = @divTrunc(width_i32 - (body_w + nub_w + 1), 2);
    const body_y: i32 = @divTrunc(height_i32 - body_h, 2);
    const nub_x: i32 = body_x + body_w + 1;
    const nub_y: i32 = body_y + @divTrunc(body_h - nub_h, 2);

    _ = c.XSetForeground(self.display, self.gc, self.border_pixel);
    _ = c.XDrawRectangle(
        self.display,
        window,
        self.gc,
        body_x,
        body_y,
        @intCast(body_w),
        @intCast(body_h),
    );
    _ = c.XFillRectangle(
        self.display,
        window,
        self.gc,
        nub_x,
        nub_y,
        @intCast(nub_w),
        @intCast(nub_h),
    );

    const inner_x: i32 = body_x + 2;
    const inner_y: i32 = body_y + 2;
    const inner_w: i32 = body_w - 3;
    const inner_h: i32 = body_h - 3;

    const clamped = @min(percent, 100);
    var fill_w: i32 = @intCast(@divTrunc(inner_w * clamped, 100));
    if (clamped > 0 and fill_w == 0) fill_w = 1;

    const fill_pixel = if (clamped < 10)
        self.crit_pixel
    else if (clamped < 30)
        self.warn_pixel
    else
        self.good_pixel;

    if (fill_w > 0) {
        _ = c.XSetForeground(self.display, self.gc, fill_pixel);
        _ = c.XFillRectangle(
            self.display,
            window,
            self.gc,
            inner_x,
            inner_y,
            @intCast(fill_w),
            @intCast(inner_h),
        );
    }
}
