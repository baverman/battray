const render = @import("render.zig");

pub const Config = struct {
    colors: struct {
        border: [:0]const u8 = "#aaaaaa",
        good: [:0]const u8 = "#aaaaaa",
        warn: [:0]const u8 = "#e0b43b",
        crit: [:0]const u8 = "#d9534f",
    } = .{},
    battery: render.Battery = .{
        .height = 0.55,
        .nub_h = 0.2,
        .nub_w = 0.1,
        .nub_gap = 0.05,
        .fill_gap = 0.05,
        .zoom = 0.85,
        .offset = 0,
    },
};

pub const config: Config = .{};
