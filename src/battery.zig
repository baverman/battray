const std = @import("std");

pub const Battery = struct {
    allocator: std.mem.Allocator,
    capacity_path: []u8,

    pub fn init(allocator: std.mem.Allocator, io: std.Io) !Battery {
        var dir = try std.Io.Dir.openDirAbsolute(io, "/sys/class/power_supply", .{ .iterate = true });
        defer dir.close(io);

        var it = dir.iterate();
        while (try it.next(io)) |entry| {
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

    pub fn readCapacity(self: *const Battery, io: std.Io) !u8 {
        var buf: [16]u8 = undefined;
        const bytes = try std.Io.Dir.cwd().readFile(io, self.capacity_path, &buf);
        const trimmed = std.mem.trim(u8, bytes, " \t\r\n");
        return try std.fmt.parseInt(u8, trimmed, 10);
    }
};
