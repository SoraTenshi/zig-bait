const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.addModule("zig-bait", .{
        .source_file = .{ .path = "bait.zig" },
    });
}
