const std = @import("std");

pub fn build(b: *std.Build) void {
    const zig_bait_tools = b.createModule(.{
        .source_file = .{ .path = "zig-bait-tools/zig-bait-tools.zig" },
    });

    _ = b.addModule("zig-bait", .{
        .source_file = .{ .path = "bait.zig" },
        .dependencies = &.{.{
            .name = "zig-bait-tools",
            .module = zig_bait_tools,
        }},
    });
}
