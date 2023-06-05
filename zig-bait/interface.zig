const std = @import("std");

const option = @import("option/option.zig");

/// The interface for hooking functions.
pub const Hook = struct {
    const Self = @This();

    /// The option for hooking.
    hook_option: option.Option,

    /// The interface for the hook function.
    hook: *const fn (option: *option.HookingOption) anyerror!void,
    /// The interface for the restore function.
    restore: *const fn (option: *option.HookingOption) void,

    /// Initialize the interface.
    pub fn init(hook: anytype, restore: anytype, hook_option: option.Option) Self {
        std.meta.trait.isPtrTo(.Fn)(hook);
        std.meta.trait.isPtrTo(.Fn)(restore);

        const self = Self{
            .hook_option = hook_option,
            .hook = hook,
            .restore = restore,
        };

        return self;
    }

    /// Hook the function.
    pub fn do_hook(self: *Self) !void {
        try self.hook(&self.hook_option);
    }

    /// Restore the function.
    pub fn do_restore(self: *Self) !void {
        self.restore(&self.hook_option);
    }
};
