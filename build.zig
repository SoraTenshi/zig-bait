const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zig_bait_tools = b.createModule(.{
        .source_file = std.Build.FileSource.relative("zig-bait-tools/zig-bait-tools.zig"),
    });

    const bait = b.addModule("zig-bait", .{
        .source_file = .{ .path = "bait.zig" },
        .dependencies = &.{.{
            .name = "zig-bait-tools",
            .module = zig_bait_tools,
        }},
    });

    const bait_test = b.addTest(.{
        .root_source_file = bait.source_file,
        .target = target,
        .optimize = optimize,
    });
    bait_test.addModule("zig-bait-tools", zig_bait_tools);

    const run_lib_tests = b.addRunArtifact(bait_test);
    const test_step = b.step("test", "Run the library tests");
    test_step.dependOn(&run_lib_tests.step);
}
