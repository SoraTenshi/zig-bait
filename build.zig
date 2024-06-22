const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zig_bait_tools = b.createModule(.{
        .root_source_file = b.path("zig-bait-tools/zig-bait-tools.zig"),
    });

    const bait = b.addModule("zig-bait", .{
        .root_source_file = b.path("bait.zig"),
        .imports = &.{.{
            .name = "zig-bait-tools",
            .module = zig_bait_tools,
        }},
    });

    const bait_test = b.addTest(.{
        .root_source_file = bait.root_source_file.?,
        .target = target,
        .optimize = optimize,
    });
    bait_test.root_module.addImport("zig-bait-tools", zig_bait_tools);

    const run_lib_tests = b.addRunArtifact(bait_test);
    const test_step = b.step("test", "Run the library tests");
    test_step.dependOn(&run_lib_tests.step);
}
