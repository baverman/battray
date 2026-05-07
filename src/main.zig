const std = @import("std");
const Battery = @import("battery.zig").Battery;
const Tray = @import("tray_x11.zig").Tray;

const refresh_interval_ms = 30 * std.time.ms_per_s;
const icon_size: u16 = 24;

pub fn main(init: std.process.Init.Minimal) !void {
    _ = init;
    const allocator = std.heap.c_allocator;

    var io_state: std.Io.Threaded = .init_single_threaded;
    const io = io_state.io();

    var battery = try Battery.init(allocator, io);
    defer battery.deinit();

    const initial_capacity = try battery.readCapacity(io);

    var tray = try Tray.init(icon_size, icon_size);
    defer tray.deinit();

    tray.setLevel(initial_capacity);

    var last_capacity = initial_capacity;
    var next_refresh_ms = currentTimeMs(io) + refresh_interval_ms;
    var poll_fds = [_]std.posix.pollfd{
        .{
            .fd = tray.connectionFd(),
            .events = std.posix.POLL.IN,
            .revents = 0,
        },
    };

    while (tray.running) {
        tray.processPending();

        const now_ms = currentTimeMs(io);
        if (now_ms >= next_refresh_ms) {
            const capacity = battery.readCapacity(io) catch |err| {
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

        const remaining_ms = @max(next_refresh_ms - currentTimeMs(io), 0);
        const timeout_ms: i32 = @intCast(remaining_ms);
        _ = try std.posix.poll(&poll_fds, timeout_ms);
    }
}

fn currentTimeMs(io: std.Io) i64 {
    return std.Io.Clock.real.now(io).toMilliseconds();
}
