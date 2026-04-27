const std = @import("std");

pub const Battery = struct {
    allocator: std.mem.Allocator,
    capacity_path: []u8,

    pub fn init(allocator: std.mem.Allocator) !Battery {
        var dir = try std.fs.openDirAbsolute("/sys/class/power_supply", .{ .iterate = true });
        defer dir.close();

        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (!std.mem.startsWith(u8, entry.name, "BAT")) continue;

            const path = try std.fmt.allocPrint(allocator, "/sys/class/power_supply/{s}/capacity", .{entry.name});
            return .{
                .allocator = allocator,
                .capacity_path = path,
            };
        }

        return error.NoBatteryFound;
    }

    pub fn deinit(self: *Battery) void {
        self.allocator.free(self.capacity_path);
    }

    pub fn readCapacity(self: *const Battery) !u8 {
        const file = try std.fs.openFileAbsolute(self.capacity_path, .{});
        defer file.close();

        const raw = try file.readToEndAlloc(self.allocator, 32);
        defer self.allocator.free(raw);

        const trimmed = std.mem.trim(u8, raw, " \t\r\n");
        return try std.fmt.parseInt(u8, trimmed, 10);
    }
};
