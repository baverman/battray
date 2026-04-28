const std = @import("std");
const Color = @import("render.zig").Color;
const drawBattery = @import("render.zig").drawBattery;
const config = @import("config.zig").config;
pub const c = @import("x11.zig").c;

const SYSTEM_TRAY_REQUEST_DOCK: c_long = 0;
const XEMBED_VERSION: c_ulong = 0;
const XEMBED_MAPPED: c_ulong = 1;

fn allocColor(display: *c.Display, colormap: c.Colormap, name: [:0]const u8) !c_ulong {
    var screen_def: c.XColor = undefined;
    var exact_def: c.XColor = undefined;
    if (c.XAllocNamedColor(display, colormap, name.ptr, &screen_def, &exact_def) == 0) {
        return error.XAllocColorFailed;
    }
    return screen_def.pixel;
}

pub const Tray = struct {
    display: *c.Display,
    screen: c_int,
    root: c.Window,
    window: c.Window,
    tray_owner: c.Window,
    atoms: Atoms,
    painter: Painter,
    width: u16,
    height: u16,
    running: bool,
    percent: u8,

    pub fn init(width: u16, height: u16) !Tray {
        const display = c.XOpenDisplay(null) orelse return error.XOpenDisplayFailed;
        errdefer _ = c.XCloseDisplay(display);

        const screen = c.XDefaultScreen(display);
        const root = c.XRootWindow(display, screen);

        const atoms = try Atoms.init(display, screen);
        const tray_owner = c.XGetSelectionOwner(display, atoms.tray_selection);
        if (tray_owner == 0) return error.SystemTrayUnavailable;

        var attrs: c.XSetWindowAttributes = std.mem.zeroInit(c.XSetWindowAttributes, .{});
        attrs.background_pixmap = c.ParentRelative;
        attrs.event_mask = c.ExposureMask | c.StructureNotifyMask;
        attrs.override_redirect = c.True;

        const depth = c.XDefaultDepth(display, screen);
        const visual = c.XDefaultVisual(display, screen);
        const window = c.XCreateWindow(
            display,
            root,
            0,
            0,
            width,
            height,
            0,
            depth,
            c.InputOutput,
            visual,
            c.CWBackPixmap | c.CWEventMask | c.CWOverrideRedirect,
            &attrs,
        );
        if (window == 0) return error.XCreateWindowFailed;
        errdefer _ = c.XDestroyWindow(display, window);

        _ = c.XStoreName(display, window, "battray");
        _ = c.XSelectInput(display, window, c.ExposureMask | c.StructureNotifyMask);

        var xembed_info = [2]c_ulong{ XEMBED_VERSION, XEMBED_MAPPED };
        _ = c.XChangeProperty(
            display,
            window,
            atoms.xembed_info,
            atoms.xembed_info,
            32,
            c.PropModeReplace,
            @ptrCast(&xembed_info),
            2,
        );

        const painter = try Painter.init(display, screen, window, width, height);
        errdefer {
            var p = painter;
            p.deinit();
        }

        var tray = Tray{
            .display = display,
            .screen = screen,
            .root = root,
            .window = window,
            .tray_owner = tray_owner,
            .atoms = atoms,
            .painter = painter,
            .width = width,
            .height = height,
            .running = true,
            .percent = 0,
        };

        try tray.dock();
        return tray;
    }

    pub fn deinit(self: *Tray) void {
        self.painter.deinit();
        _ = c.XDestroyWindow(self.display, self.window);
        _ = c.XCloseDisplay(self.display);
    }

    pub fn setLevel(self: *Tray, percent: u8) void {
        self.percent = @min(percent, 100);
        self.redraw();
    }

    pub fn processPending(self: *Tray) void {
        while (c.XPending(self.display) > 0) {
            var event: c.XEvent = undefined;
            _ = c.XNextEvent(self.display, &event);
            self.handleEvent(&event);
        }
    }

    pub fn connectionFd(self: *const Tray) std.posix.fd_t {
        return c.XConnectionNumber(self.display);
    }

    fn dock(self: *Tray) !void {
        var event: c.XEvent = undefined;
        @memset(std.mem.asBytes(&event), 0);
        event.xclient.type = c.ClientMessage;
        event.xclient.serial = 0;
        event.xclient.send_event = 1;
        event.xclient.message_type = self.atoms.system_tray_opcode;
        event.xclient.window = self.window;
        event.xclient.format = 32;
        event.xclient.data.l[0] = c.CurrentTime;
        event.xclient.data.l[1] = SYSTEM_TRAY_REQUEST_DOCK;
        event.xclient.data.l[2] = @intCast(self.window);
        event.xclient.data.l[3] = 0;
        event.xclient.data.l[4] = 0;

        if (c.XSendEvent(self.display, self.tray_owner, 0, c.NoEventMask, &event) == 0) {
            return error.XSendEventFailed;
        }
        _ = c.XMapWindow(self.display, self.window);
        _ = c.XFlush(self.display);
    }

    fn handleEvent(self: *Tray, event: *c.XEvent) void {
        switch (event.type) {
            c.Expose => {
                if (event.xexpose.count == 0) self.redraw();
            },
            c.ConfigureNotify => {
                const new_width: u16 = @intCast(@max(event.xconfigure.width, 1));
                const new_height: u16 = @intCast(@max(event.xconfigure.height, 1));
                if (new_width != self.width or new_height != self.height) {
                    self.width = new_width;
                    self.height = new_height;
                    self.painter.resize(new_width, new_height);
                    self.redraw();
                }
            },
            c.DestroyNotify => {
                if (event.xdestroywindow.window == self.window) {
                    self.running = false;
                }
            },
            else => {},
        }
    }

    fn redraw(self: *Tray) void {
        _ = c.XClearWindow(self.display, self.window);
        drawBattery(&self.painter, self.percent);
        _ = c.XFlush(self.display);
    }
};

const Atoms = struct {
    tray_selection: c.Atom,
    system_tray_opcode: c.Atom,
    xembed_info: c.Atom,

    fn init(display: *c.Display, screen: c_int) !Atoms {
        var selection_name_buf: [32]u8 = undefined;
        const selection_name = try std.fmt.bufPrintZ(&selection_name_buf, "_NET_SYSTEM_TRAY_S{}", .{screen});

        const tray_selection = c.XInternAtom(display, selection_name.ptr, c.False);
        const system_tray_opcode = c.XInternAtom(display, "_NET_SYSTEM_TRAY_OPCODE", c.False);
        const xembed_info = c.XInternAtom(display, "_XEMBED_INFO", c.False);

        if (tray_selection == 0 or system_tray_opcode == 0 or xembed_info == 0) {
            return error.XInternAtomFailed;
        }

        return .{
            .tray_selection = tray_selection,
            .system_tray_opcode = system_tray_opcode,
            .xembed_info = xembed_info,
        };
    }
};

pub const Painter = struct {
    display: *c.Display,
    colormap: c.Colormap,
    window: c.Window,
    gc: c.GC,
    width: i32,
    height: i32,

    color_border: c_ulong,
    color_good: c_ulong,
    color_warn: c_ulong,
    color_crit: c_ulong,

    pub fn init(display: *c.Display, screen: c_int, window: c.Window, width: i32, height: i32) !Painter {
        const colormap = c.XDefaultColormap(display, screen);
        const gc = c.XCreateGC(display, window, 0, null) orelse return error.XCreateGCFailed;
        errdefer _ = c.XFreeGC(display, gc);

        return .{
            .display = display,
            .colormap = colormap,
            .window = window,
            .gc = gc,
            .width = width,
            .height = height,
            .color_border = try allocColor(display, colormap, config.colors.border),
            .color_good = try allocColor(display, colormap, config.colors.good),
            .color_warn = try allocColor(display, colormap, config.colors.warn),
            .color_crit = try allocColor(display, colormap, config.colors.crit),
        };
    }

    pub fn deinit(self: *Painter) void {
        _ = c.XFreeGC(self.display, self.gc);
    }

    pub fn getColor(self: *Painter, color: Color) c_ulong {
        return switch (color) {
            Color.border => self.color_border,
            Color.good => self.color_good,
            Color.warn => self.color_warn,
            Color.crit => self.color_crit,
        };
    }

    pub fn drawRect(self: *Painter, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        _ = c.XSetForeground(self.display, self.gc, self.getColor(color));
        _ = c.XDrawRectangle(self.display, self.window, self.gc, x, y, @intCast(w), @intCast(h));
    }

    pub fn drawFillRect(self: *Painter, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        _ = c.XSetForeground(self.display, self.gc, self.getColor(color));
        _ = c.XFillRectangle(self.display, self.window, self.gc, x, y, @intCast(w), @intCast(h));
    }

    pub fn resize(self: *Painter, width: i32, height: i32) void {
        self.width = width;
        self.height = height;
    }
};
