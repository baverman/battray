const std = @import("std");
const Tray = @import("tray_x11.zig").Tray;

const icon_size: u16 = 24;

pub fn main(init: std.process.Init.Minimal) !void {
    const allocator = std.heap.c_allocator;

    var io_state: std.Io.Threaded = .init_single_threaded;
    const io = io_state.io();

    var environ_map = try init.environ.createMap(allocator);
    defer environ_map.deinit();

    var tray = try Tray.init(allocator, io, &environ_map, icon_size, icon_size);
    defer tray.deinit();

    try tray.run(allocator, io);
}
