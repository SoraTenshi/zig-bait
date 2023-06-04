const std = @import("std");

const option = @import("hooking_option.zig");

pub const Hook = struct {
    const Self = @This();

    hook_option: option.HookingOption,

    hook: *const fn (option: *option.HookingOption) anyerror!void,
    restore: *const fn (option: *option.HookingOption) void,

    pub fn init(hook: anytype, restore: anytype, hook_option: option.HookingOption) Self {
        std.meta.trait.isPtrTo(.Fn)(hook);
        std.meta.trait.isPtrTo(.Fn)(restore);

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
