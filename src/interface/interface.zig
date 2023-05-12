const std = @import("std");
const fn_ptr = @import("fn_ptr/func_ptr.zig");

const option = @import("hooking_option.zig");

pub const Hook = struct {
    const Self = @This();

    hook_option: option.HookingOption,

    hook: *const fn (self: *Hook) anyerror!void,
    unhook: *const fn (self: *Self) void,

    pub fn init(hook: anytype, unhook: anytype, hook_option: option.HookingOption) Self {
        fn_ptr.checkIfFnPtr(hook);
        fn_ptr.checkIfFnPtr(unhook);

        const self = Self{
            .hook_option = hook_option,
            .hook = hook,
            .unhook = unhook,
        };

        return self;
    }

    pub fn do_hook(self: *Hook) !void {
        try self.hook(self);
    }

    pub fn do_unhook(self: *Self) !void {
        self.unhook();
    }
};

fn h(_: *Hook) anyerror!void {
    return error.Nice;
}

fn u(_: *Hook) void {
    return;
}

test {
    var c = try std.testing.allocator.create([*c]usize);
    defer std.testing.allocator.destroy(c);
    var hook = Hook.init(&h, &u, option.HookingOption{ .vmt_option = option.VmtOption{
        .base = c,
        .offset = 0x0,
        .index = 0x0,
        .original = null,
    } });

    try std.testing.expectError(error.Nice, hook.do_hook());
}
