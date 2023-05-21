const std = @import("std");
const fn_ptr = @import("fn_ptr/func_ptr.zig");

const option = @import("hooking_option.zig");

pub const Hook = struct {
    const Self = @This();

    hook_option: option.HookingOption,

    hook: *const fn (option: *option.HookingOption) anyerror!void,
    restore: *const fn (option: *option.HookingOption) void,

    pub fn init(hook: anytype, restore: anytype, hook_option: option.HookingOption) Self {
        fn_ptr.checkIfFnPtr(hook);
        fn_ptr.checkIfFnPtr(restore);

        const self = Self{
            .hook_option = hook_option,
            .hook = hook,
            .restore = restore,
        };

        return self;
    }

    pub fn do_hook(self: *Self) !void {
        try self.hook(&self.hook_option);
    }

    pub fn do_restore(self: *Self) !void {
        self.restore(&self.hook_option);
    }
};

fn h(_: *option.HookingOption) anyerror!void {
    return error.Nice;
}

fn u(_: *option.HookingOption) void {
    return;
}

test {
    var c = try std.testing.allocator.create([*c]usize);
    defer std.testing.allocator.destroy(c);

    var b = try std.testing.allocator.create([*c]usize);
    defer std.testing.allocator.destroy(b);

    var hook = Hook.init(&h, &u, option.HookingOption{ .vmt_option = option.VmtOption{
        .base = c.*,
        .index = 0x0,
        .original = b.*,
    } });

    try std.testing.expectError(error.Nice, hook.do_hook());
}
