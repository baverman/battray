const std = @import("std");
const zix11 = @import("zix11");
const x = zix11.xproto;
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
        var conn = try zix11.Connection.connectFromEnv(allocator, io, environ_map);
        errdefer conn.deinit();

        const atoms = try Atoms.init(&conn);
        const owner_reply = try conn.request(x.GetSelectionOwner, .{
            .selection = atoms.tray_selection,
        });
        if (@intFromEnum(owner_reply.owner) == 0) return error.SystemTrayUnavailable;

        const window = try conn.allocId(x.Window);
        try conn.request(x.CreateWindow, .{
            .depth = 0,
            .wid = window,
            .parent = conn.root_window,
            .x = 0,
            .y = 0,
            .width = @intCast(width),
            .height = @intCast(height),
            .border_width = 0,
            .class = .InputOutput,
            .visual = 0,
            .value_list = .{
                .background_pixmap = parent_relative,
                .event_mask = x.EventMask.of(&.{ .Exposure, .StructureNotify }),
                .override_redirect = 1,
            },
        });
        errdefer conn.request(x.DestroyWindow, .{ .window = window }) catch {};

        const gc = try conn.allocId(x.Gcontext);
        try conn.request(x.CreateGC, .{
            .cid = gc,
            .drawable = .{ .window = window },
            .value_list = .{
                .graphics_exposures = 0,
            },
        });
        errdefer conn.request(x.FreeGC, .{ .gc = gc }) catch {};

        try setXembedInfo(&conn, window, atoms.xembed_info);

        var tray = Tray{
            .allocator = allocator,
            .io = io,
            .conn = conn,
            .window = window,
            .tray_owner = owner_reply.owner,
            .atoms = atoms,
            .gc = gc,
            .width = width,
            .height = height,
            .running = true,
            .percent = 0,
        };
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

    pub fn handleEvent(self: *Tray, event: x.Event) !void {
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

    fn dock(self: *Tray) !void {
        const event: x.ClientMessageEvent = .{
            .window = self.window,
            .type = self.atoms.system_tray_opcode,
            .format = 32,
            .data = zix11.clientMessageData(u32, &.{ 0, SYSTEM_TRAY_REQUEST_DOCK, @intFromEnum(self.window) }),
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

const Atoms = struct {
    tray_selection: x.Atom,
    system_tray_opcode: x.Atom,
    xembed_info: x.Atom,

    fn init(conn: *zix11.Connection) !Atoms {
        return .{
            .tray_selection = try internAtom(conn, "_NET_SYSTEM_TRAY_S0"),
            .system_tray_opcode = try internAtom(conn, "_NET_SYSTEM_TRAY_OPCODE"),
            .xembed_info = try internAtom(conn, "_XEMBED_INFO"),
        };
    }
};

fn internAtom(conn: *zix11.Connection, name: []const u8) !x.Atom {
    const reply = try conn.request(x.InternAtom, .{
        .only_if_exists = false,
        .name = name,
    });
    return reply.atom;
}

fn setXembedInfo(conn: *zix11.Connection, window: x.Window, xembed_info: x.Atom) !void {
    var data: [8]u8 = undefined;
    std.mem.writeInt(u32, data[0..4], XEMBED_VERSION, .little);
    std.mem.writeInt(u32, data[4..8], XEMBED_MAPPED, .little);
    try conn.request(x.ChangeProperty, .{
        .mode = .Replace,
        .window = window,
        .property = xembed_info,
        .type = xembed_info,
        .format = 32,
        .data_len = 2,
        .data = data[0..],
    });
}

fn currentTimeMs(io: std.Io) i64 {
    return std.Io.Clock.real.now(io).toMilliseconds();
}
