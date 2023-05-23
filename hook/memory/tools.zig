const std = @import("std");

pub fn memcpy(target: []?usize, src: []const usize) void {
    std.mem.copyForwards(usize, target, src);
}
