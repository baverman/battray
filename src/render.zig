pub const Color = enum {
    border,
    crit,
    warn,
    good,
};

pub fn drawBattery(painter: anytype, percent: u8) void {
    const width_i32: i32 = painter.width;
    const height_i32: i32 = painter.height;

    const body_w: i32 = 16;
    const body_h: i32 = 10;
    const nub_w: i32 = 2;
    const nub_h: i32 = 4;

    const body_x: i32 = @divTrunc(width_i32 - (body_w + nub_w + 1), 2);
    const body_y: i32 = @divTrunc(height_i32 - body_h, 2);
    const nub_x: i32 = body_x + body_w + 1;
    const nub_y: i32 = body_y + @divTrunc(body_h - nub_h, 2);

    painter.drawRect(body_x, body_y, @intCast(body_w), @intCast(body_h), Color.border);
    painter.drawFillRect(nub_x, nub_y, @intCast(nub_w), @intCast(nub_h), Color.border);

    const inner_x: i32 = body_x + 2;
    const inner_y: i32 = body_y + 2;
    const inner_w: i32 = body_w - 3;
    const inner_h: i32 = body_h - 3;

    const clamped = @min(percent, 100);
    var fill_w: i32 = @intCast(@divTrunc(inner_w * clamped, 100));
    if (clamped > 0 and fill_w == 0) fill_w = 1;

    const fill_color = if (clamped < 10)
        Color.crit
    else if (clamped < 30)
        Color.warn
    else
        Color.good;

    if (fill_w > 0) {
        painter.drawFillRect(inner_x, inner_y, fill_w, inner_h, fill_color);
    }
}
