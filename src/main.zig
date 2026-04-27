const std = @import("std");
const Battery = @import("battery.zig").Battery;
const Tray = @import("tray_x11.zig").Tray;

const refresh_interval_ms = 30 * std.time.ms_per_s;
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

    tray.setLevel(initial_capacity);

    var last_capacity = initial_capacity;
    var next_refresh_ms = std.time.milliTimestamp() + refresh_interval_ms;
    var poll_fds = [_]std.posix.pollfd{
        .{
            .fd = tray.connectionFd(),
            .events = std.posix.POLL.IN,
            .revents = 0,
        },
    };

    while (tray.running) {
        tray.processPending();

        const now_ms = std.time.milliTimestamp();
        if (now_ms >= next_refresh_ms) {
            const capacity = battery.readCapacity() catch |err| {
                std.log.err("failed to read battery capacity: {}", .{err});
                next_refresh_ms = now_ms + refresh_interval_ms;
                continue;
            };

            if (capacity != last_capacity) {
                tray.setLevel(capacity);
                last_capacity = capacity;
            }

            next_refresh_ms = now_ms + refresh_interval_ms;
        }

        const remaining_ms = @max(next_refresh_ms - std.time.milliTimestamp(), 0);
        const timeout_ms: i32 = @intCast(remaining_ms);
        _ = try std.posix.poll(&poll_fds, timeout_ms);
    }
}
