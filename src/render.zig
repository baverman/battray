pub const Color = enum {
    border,
    crit,
    warn,
    good,
};

pub const Battery = struct {
    height: f32 = 0.55,
    nub_h: f32 = 0.2,
    nub_w: f32 = 0.1,
    nub_gap: f32 = 0.05,
    fill_gap: f32 = 0.05,
    zoom: f32 = 0.85,
    offset: i32 = 0,
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

pub fn drawBattery(painter: anytype, percent: u8, width: i32, height: i32) void {
    var l: Layout = undefined;
    const battery: Battery = .{};
    calcLayout(&l, &battery, width, height);

    painter.drawRect(l.body.x, l.body.y, l.body.w, l.body.h, Color.border);
    painter.drawFillRect(l.nub.x, l.nub.y, l.nub.w, l.nub.h, Color.border);

    const clamped = @min(percent, 100);
    const fill_w: i32 = @divTrunc(l.fill.w * clamped + 50, 100);

    const fill_color = if (clamped < 10)
        Color.crit
    else if (clamped < 30)
        Color.warn
    else
        Color.good;

    if (fill_w > 0) {
        painter.drawFillRect(l.fill.x, l.fill.y, fill_w, l.fill.h, fill_color);
    }
}

pub fn calcLayout(out: *Layout, battery: *const Battery, width: i32, height: i32) void {
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

    out.body = .{
        .x = @divTrunc(width - real_w, 2),
        .y = @divTrunc(height - bh, 2) + battery.offset,
        .w = bw,
        .h = bh,
    };

    out.fill = .{
        .x = out.body.x + 1 + fg,
        .y = out.body.y + 1 + fg,
        .w = out.body.w - 2 - 2 * fg,
        .h = out.body.h - 2 - 2 * fg,
    };

    out.nub = .{
        .x = out.body.x + out.body.w + ng,
        .y = @divTrunc(height - nh, 2) + battery.offset,
        .w = nw,
        .h = nh,
    };

    // const std = @import("std");
    // std.debug.print("Result: {any}\n", .{out.*});
}
