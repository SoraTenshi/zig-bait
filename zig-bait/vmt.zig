const std = @import("std");
const builtin = @import("builtin");
const win = std.os.windows;
const lin = std.os.linux;

const tools = @import("zig-bait-tools");
const interface = @import("interface.zig");
const option = @import("option/option.zig");

const Allocator = std.mem.Allocator;

fn hook(opt: *option.Option) anyerror!void {
    var unwrapped = switch (opt.*) {
        .vmt => |*o| o,
    };

    const ptr = tools.Address.init(unwrapped.base.*);
    const new_flags = tools.getFlags(tools.Flags.readwrite);

    for (unwrapped.index_map) |*map| {
        const old = try tools.setNewProtect(ptr, map.position, new_flags) orelse tools.getFlags(tools.Flags.read);
        defer _ = tools.setNewProtect(ptr, map.position, old) catch {};
        map.restore = unwrapped.base.*[map.position];
        unwrapped.base.*[map.position] = map.target;
    }
}

fn restore(opt: *option.Option) void {
    var unwrapped = switch (opt.*) {
        .vmt => |*o| o,
    };

    for (unwrapped.index_map) |map| {
        unwrapped.base.*[map.position] = map.restore.?;
        hook(option) catch @panic("Restoring the original vtable failed.");
    }
}

pub fn init(alloc: Allocator, base_class: tools.AbstractClass, comptime positions: []const usize, targets: []const usize) !interface.Hook {
    var opt = option.vmt.VmtOption.init(alloc, base_class, positions, targets);
    var self = interface.Hook.init(&hook, &restore, option.Option{ .vmt = opt });

    try self.do_hook();
    return self;
}
