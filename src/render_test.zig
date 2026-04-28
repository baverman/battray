const std = @import("std");
const t = @import("std").testing;

const Color = @import("render.zig").Color;
const drawBattery = @import("render.zig").drawBattery;
const Battery = @import("render.zig").Battery;
const calcLayout = @import("render.zig").calcLayout;

const battery: Battery = .{
    .height = 0.55,
    .nub_h = 0.2,
    .nub_w = 0.1,
    .nub_gap = 0.05,
    .fill_gap = 0.05,
    .zoom = 0.85,
    .offset = 0,
};

const Painter = struct {
    buf: [100][100]u8,

    pub fn init() Painter {
        var result: Painter = .{ .buf = std.mem.zeroes([100][100]u8) };
        result.clear();
        return result;
    }

    pub fn clear(self: *Painter) void {
        for (&self.buf) |*row| {
            @memset(row, '.');
        }
    }

    pub fn getColor(color: Color) u8 {
        return switch (color) {
            Color.border => '#',
            Color.good => '*',
            Color.warn => 'w',
            Color.crit => 'c',
        };
    }

    fn hline(self: *Painter, x: i32, y: i32, length: i32, color: Color) void {
        const cx: usize = @max(x, 0);
        const cy: usize = @max(y, 0);
        const cl: usize = @max(length, 0);
        const c = getColor(color);
        for (0..cl) |i| {
            self.buf[cy][cx + i] = c;
        }
    }

    fn vline(self: *Painter, x: i32, y: i32, length: i32, color: Color) void {
        const cx: usize = @max(x, 0);
        const cy: usize = @max(y, 0);
        const cl: usize = @max(length, 0);
        const c = getColor(color);
        for (0..cl) |i| {
            self.buf[cy + i][cx] = c;
        }
    }

    pub fn drawRect(self: *Painter, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        self.hline(x, y, w, color);
        self.hline(x, y + h - 1, w, color);
        self.vline(x, y, h, color);
        self.vline(x + w - 1, y, h, color);
    }

    pub fn drawFillRect(self: *Painter, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        const ch: usize = @max(h, 0);
        for (0..ch) |i| {
            self.hline(x, y + @as(i32, @intCast(i)), w, color);
        }
    }

    pub fn dump(self: *Painter, out: []u8, w: usize, h: usize) []const u8 {
        var pos: usize = 0;
        for (0..h) |i| {
            std.mem.copyForwards(u8, out[pos..], self.buf[i][0..w]);
            pos += w;
            out[pos] = '\n';
            pos += 1;
        }
        return out[0 .. pos - 1];
    }
};

test "Test testing implementation" {
    var out = [_]u8{0} ** 1000;
    var p = Painter.init();

    p.drawRect(1, 1, 5, 3, Color.border);
    var expected =
        \\.......
        \\.#####.
        \\.#...#.
        \\.#####.
        \\.......
    ;
    try t.expectEqualStrings(expected, p.dump(&out, 7, 5));

    p.clear();
    p.drawFillRect(1, 1, 5, 3, Color.border);
    expected =
        \\.......
        \\.#####.
        \\.#####.
        \\.#####.
        \\.......
    ;
    try t.expectEqualStrings(expected, p.dump(&out, 7, 5));
}

test "Test 99% should still be full" {
    var out = [_]u8{0} ** 1000;
    var p = Painter.init();

    drawBattery(&p, 99, calcLayout(battery, 22, 22));
    const expected =
        \\......................
        \\......................
        \\......................
        \\......................
        \\......................
        \\......................
        \\.################.....
        \\.#..............#.....
        \\.#.************.#.....
        \\.#.************.#.##..
        \\.#.************.#.##..
        \\.#.************.#.##..
        \\.#.************.#.##..
        \\.#.************.#.....
        \\.#..............#.....
        \\.################.....
        \\......................
        \\......................
        \\......................
        \\......................
        \\......................
        \\......................
    ;
    try t.expectEqualStrings(expected, p.dump(&out, 22, 22));
}

test "Test 10x10 render stays coherent" {
    var out = [_]u8{0} ** 1000;
    var p = Painter.init();

    drawBattery(&p, 99, calcLayout(battery, 10, 10));
    const expected =
        \\..........
        \\..........
        \\#######...
        \\#.....#.#.
        \\#.***.#.#.
        \\#.....#.#.
        \\#######...
        \\..........
        \\..........
        \\..........
    ;
    try t.expectEqualStrings(expected, p.dump(&out, 10, 10));
}
