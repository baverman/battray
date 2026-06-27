const std = @import("std");

pub fn move(value: anytype) std.meta.Child(@TypeOf(value)) {
    defer value.* = undefined;
    return value.*;
}
