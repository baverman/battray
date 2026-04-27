const std = @import("std");
const Battery = @import("battery.zig").Battery;
const Tray = @import("tray_x11.zig").Tray;

const refresh_interval_ns = 30 * std.time.ns_per_s;
const sleep_interval_ns = 100 * std.time.ns_per_ms;
const icon_size: u16 = 24;

pub fn main() !void {
    var gpa_state: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer {
        const leaked = gpa_state.deinit();
        if (leaked == .leak) {
            std.log.err("memory leak detected", .{});
        }
    }
    const allocator = gpa_state.allocator();

    var battery = try Battery.init(allocator);
    defer battery.deinit();

    const initial_capacity = try battery.readCapacity();

    var tray = try Tray.init(icon_size, icon_size);
    defer tray.deinit();

    var text_buf: [4]u8 = undefined;
    const initial_text = try std.fmt.bufPrint(&text_buf, "{d}", .{initial_capacity});
    try tray.setText(initial_text);

    var last_capacity = initial_capacity;
    var next_refresh = std.time.nanoTimestamp();

    while (tray.running) {
        tray.processPending();

        const now = std.time.nanoTimestamp();
        if (now >= next_refresh) {
            const capacity = battery.readCapacity() catch |err| {
                std.log.err("failed to read battery capacity: {}", .{err});
                next_refresh = now + refresh_interval_ns;
                std.Thread.sleep(sleep_interval_ns);
                continue;
            };

            if (capacity != last_capacity) {
                const text = try std.fmt.bufPrint(&text_buf, "{d}", .{capacity});
                try tray.setText(text);
                last_capacity = capacity;
            }

            next_refresh = now + refresh_interval_ns;
        }

        std.Thread.sleep(sleep_interval_ns);
    }
}
