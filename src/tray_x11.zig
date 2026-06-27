const std = @import("std");
const zix11 = @import("zix11");
const x = zix11.x;

const move = @import("util.zig").move;
const Battery = @import("battery.zig").Battery;
const render = @import("render.zig");
const config = @import("config.zig").config;
const X11Painter = @import("x11_painter.zig").X11Painter;

const SYSTEM_TRAY_REQUEST_DOCK: u32 = 0;
const XEMBED_VERSION: u32 = 0;
const XEMBED_MAPPED: u32 = 1;
const parent_relative: x.Pixmap = @enumFromInt(1);

pub const Tray = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    conn: zix11.Connection,
    window: x.Window,
    tray_owner: x.Window,
    atoms: Atoms,
    gc: x.Gcontext,
    width: i32,
    height: i32,
    running: bool,
    percent: u8,

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        environ_map: *const std.process.Environ.Map,
        width: i32,
        height: i32,
    ) !Tray {
        var conn = try zix11.Connection.init(allocator, io);
        conn.connectFromEnv(environ_map) catch |err| {
            conn.deinit();
            return err;
        };

        var tray: Tray = .{
            .allocator = allocator,
            .io = io,
            .conn = move(&conn),
            .window = undefined,
            .tray_owner = undefined,
            .atoms = undefined,
            .gc = undefined,
            .width = width,
            .height = height,
            .running = true,
            .percent = 0,
        };

        errdefer tray.conn.deinit();
        tray.atoms = try zix11.atoms.getAll(Atoms, &tray.conn);

        try tray.createWindow();
        try tray.dock();
        return tray;
    }

    pub fn deinit(self: *Tray) void {
        self.conn.request(x.FreeGC, .{ .gc = self.gc }) catch {};
        self.conn.request(x.DestroyWindow, .{ .window = self.window }) catch {};
        self.conn.deinit();
    }

    pub fn setLevel(self: *Tray, percent: u8) !void {
        self.percent = @min(percent, 100);
        try self.redraw();
    }

    pub fn run(self: *Tray) !void {
        var battery = try Battery.init(self.allocator, self.io);
        defer battery.deinit();

        const initial_capacity = try battery.readCapacity(self.io);
        try self.setLevel(initial_capacity);

        var last_capacity = initial_capacity;

        while (self.running) {
            if (try self.conn.pollEventTimeout(30000)) |event| {
                try self.handleEvent(event);
            } else {
                const capacity = battery.readCapacity(self.io) catch |err| {
                    std.log.err("failed to read battery capacity: {}", .{err});
                    continue;
                };

                if (capacity != last_capacity) {
                    try self.setLevel(capacity);
                    last_capacity = capacity;
                }
            }
        }
    }

    pub fn handleEvent(self: *Tray, event: zix11.events.Event) !void {
        switch (event) {
            .Expose => |ev| {
                if (ev.window == self.window and ev.count == 0) {
                    try self.redraw();
                }
            },
            .ConfigureNotify => |ev| {
                if (ev.window != self.window) return;
                const new_width = @max(@as(i32, ev.width), 1);
                const new_height = @max(@as(i32, ev.height), 1);
                if (new_width != self.width or new_height != self.height) {
                    self.width = new_width;
                    self.height = new_height;
                    try self.redraw();
                }
            },
            .DestroyNotify => |ev| {
                if (ev.window == self.window) {
                    self.running = false;
                }
            },
            else => {},
        }
    }

    fn createWindow(self: *Tray) !void {
        const owner_reply = try self.conn.request(x.GetSelectionOwner, .{
            .selection = self.atoms._NET_SYSTEM_TRAY_S0,
        });
        if (owner_reply.owner == x.Window.None) return error.SystemTrayUnavailable;
        self.tray_owner = owner_reply.owner;

        self.window = try self.conn.allocId(x.Window);
        try self.conn.request(x.CreateWindow, .{
            .depth = 0,
            .wid = self.window,
            .parent = self.conn.rootWindow(),
            .x = 0,
            .y = 0,
            .width = @intCast(self.width),
            .height = @intCast(self.height),
            .border_width = 0,
            .class = .InputOutput,
            .visual = 0,
            .value_list = .{
                .background_pixmap = parent_relative,
                .event_mask = x.EventMask.of(&.{ .Exposure, .StructureNotify }),
                .override_redirect = 1,
            },
        });
        errdefer self.conn.request(x.DestroyWindow, .{ .window = self.window }) catch {};

        self.gc = try self.conn.allocId(x.Gcontext);
        try self.conn.request(x.CreateGC, .{
            .cid = self.gc,
            .drawable = .{ .window = self.window },
            .value_list = .{
                .graphics_exposures = 0,
            },
        });
        errdefer self.conn.request(x.FreeGC, .{ .gc = self.gc }) catch {};

        try zix11.properties.setAs(
            &self.conn,
            self.window,
            self.atoms._XEMBED_INFO,
            self.atoms._XEMBED_INFO,
            &[_]u32{ XEMBED_VERSION, XEMBED_MAPPED },
        );
    }

    fn dock(self: *Tray) !void {
        const event: x.ClientMessageEvent = .{
            .window = self.window,
            .type = self.atoms._NET_SYSTEM_TRAY_OPCODE,
            .format = 32,
            .data = zix11.events.clientMessageData(u32, &.{ 0, SYSTEM_TRAY_REQUEST_DOCK, @intFromEnum(self.window) }),
        };
        try self.conn.request(x.SendEvent, .{
            .propagate = false,
            .destination = self.tray_owner,
            .event_mask = 0,
            .event = try event.toBytes(),
        });
        try self.conn.request(x.MapWindow, .{ .window = self.window });
    }

    fn redraw(self: *Tray) !void {
        try self.conn.request(x.ClearArea, .{
            .exposures = false,
            .window = self.window,
            .x = 0,
            .y = 0,
            .width = @intCast(self.width),
            .height = @intCast(self.height),
        });
        const layout = render.calcLayout(config.battery, self.width, self.height);
        var painter = X11Painter.init(&self.conn, self.window, self.gc);
        try render.drawBattery(&painter, self.percent, layout);
    }
};

const Atoms = zix11.atoms.AtomStruct(enum {
    _NET_SYSTEM_TRAY_S0,
    _NET_SYSTEM_TRAY_OPCODE,
    _XEMBED_INFO,
});

fn currentTimeMs(io: std.Io) i64 {
    return std.Io.Clock.real.now(io).toMilliseconds();
}
