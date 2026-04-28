pub const Color = enum {
    border,
    crit,
    warn,
    good,
};

pub const Battery = struct {
    height: f32,
    nub_h: f32,
    nub_w: f32,
    nub_gap: f32,
    fill_gap: f32,
    zoom: f32,
    offset: i32,
};

pub const Rect = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,
};

pub const Layout = struct {
    body: Rect,
    nub: Rect,
    fill: Rect,
};

pub fn drawBattery(painter: anytype, percent: u8, layout: Layout) void {
    painter.drawRect(layout.body.x, layout.body.y, layout.body.w, layout.body.h, Color.border);
    painter.drawFillRect(layout.nub.x, layout.nub.y, layout.nub.w, layout.nub.h, Color.border);

    const clamped = @min(percent, 100);
    const fill_w: i32 = @divTrunc(layout.fill.w * clamped + 50, 100);

    const fill_color = if (clamped < 10)
        Color.crit
    else if (clamped < 30)
        Color.warn
    else
        Color.good;

    if (fill_w > 0) {
        painter.drawFillRect(layout.fill.x, layout.fill.y, fill_w, layout.fill.h, fill_color);
    }
}

pub fn calcLayout(battery: Battery, width: i32, height: i32) Layout {
    const zw = @as(f32, @floatFromInt(width)) * battery.zoom;
    const fullw = @max(1, @as(i32, @intFromFloat(@round(zw))));
    const nw = @max(1, @as(i32, @intFromFloat(@round(zw * battery.nub_w))));
    var nh = @max(1, @as(i32, @intFromFloat(@round(zw * battery.nub_h))));
    const ng = @max(1, @as(i32, @intFromFloat(@round(zw * battery.nub_gap))));
    const fg = @max(1, @as(i32, @intFromFloat(@round(zw * battery.fill_gap))));
    const bh = @max(3 + 2 * fg, @as(i32, @intFromFloat(@round(zw * (battery.height)))));
    const bw = @max(3 + 2 * fg, fullw - nw - ng);
    const real_w = bw + ng + nw;

    if ((bh % 2) != (nh % 2)) {
        nh += 1;
    }

    const bx = @divTrunc(width - real_w, 2);
    const by = @divTrunc(height - bh, 2) + battery.offset;

    return .{
        .body = .{
            .x = bx,
            .y = by,
            .w = bw,
            .h = bh,
        },

        .fill = .{
            .x = bx + 1 + fg,
            .y = by + 1 + fg,
            .w = bw - 2 - 2 * fg,
            .h = bh - 2 - 2 * fg,
        },

        .nub = .{
            .x = bx + bw + ng,
            .y = @divTrunc(height - nh, 2) + battery.offset,
            .w = nw,
            .h = nh,
        },
    };
}
