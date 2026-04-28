pub const Config = struct {
    colors: struct {
        border: [:0]const u8 = "#aaaaaa",
        good: [:0]const u8 = "#5fd35f",
        warn: [:0]const u8 = "#e0b43b",
        crit: [:0]const u8 = "#d9534f",
    } = .{},
};

pub const config: Config = .{};
