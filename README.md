# battray

X11 tray icon to display battery charge level

![battray screenshot](images/screenshot.png)

## What this is

`battray` is a small native Linux battery tray app written in Zig for X11 desktops.
It docks into an XEmbed-compatible system tray and renders the current battery level
as a simple battery-shaped icon.

The app reads battery state from `/sys/class/power_supply/BAT*/capacity` and updates
the tray icon periodically.

## How to build

Requirements:

- Zig (>=0.16)

Build with:

```bash
zig build
```
