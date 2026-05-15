const render = @import("render.zig");

pub const Config = struct {
    colors: struct {
        border: u32 = 0xaaaaaa,
        good: u32 = 0xaaaaaa,
        warn: u32 = 0xe0b43b,
        crit: u32 = 0xd9534f,
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

    pub fn rgbColorSet(self: *const Config) render.RGBColorSet {
        return .init(.{
            .border = self.colors.border,
            .crit = self.colors.crit,
            .warn = self.colors.warn,
            .good = self.colors.good,
        });
    }
};

pub const config: Config = .{};
