// std
const std = @import("std");

// Public utils
const tools = @import("zig-bait-tools");

// All the VMT utils
const vmt = @import("vmt.zig");
const safe_vmt = @import("safe_vmt.zig");
const detour = @import("detour.zig");

const HookingInterface = @import("interface.zig").Hook;
const HookList = std.ArrayList(HookingInterface);

/// The options required for VMT hooking
pub const VmtOptions = struct {
    object_address: usize,
    positions: []const usize,
    targets: []const usize,
};

/// WARN: NOT SUPPORTED YET
pub const DetourOptions = struct {
    source: struct {
        address: usize,
        len: usize,
    },
    target: struct {
        address: usize,
        len: usize,
    },
};

/// The method of hooking to use
pub const Method = union(enum) {
    vmt: VmtOptions,
    safe_vmt: VmtOptions,
    detour: DetourOptions,
};

/// The hook manager
pub const HookManager = struct {
    const Node = struct {
        position: usize,
        target: usize,
    };

    hooks: HookList,
    alloc: std.mem.Allocator,
    size: usize,

    target_to_index: std.ArrayList(Node),

    /// Init, best used with an Arena allocator
    pub fn init(alloc: std.mem.Allocator) HookManager {
        return HookManager{
            .hooks = HookList.init(alloc),
            .alloc = alloc,
            .target_to_index = std.ArrayList(Node).init(alloc),
            .size = 0,
        };
    }

    /// Restore all hooks and deinit the array list
    pub fn deinit(self: *HookManager) void {
        defer self.hooks.deinit();

        for (self.hooks.items) |*item| {
            item.doRestore();
        }
    }

    /// Gets the index from the address of the hook address
    pub fn getPositionFromTarget(self: HookManager, target: usize) ?usize {
        for (self.target_to_index.items) |item| {
            if (item.target == target) {
                return item.position;
            }
        }

        return null;
    }

    /// Gets the index from the address of the hook address
    fn getIndexFromTarget(self: HookManager, target: usize) ?usize {
        for (self.target_to_index.items, 0..) |item, i| {
            if (item.target == target) {
                return i;
            }
        }

        return null;
    }

    /// Gets the original function pointer to call
    pub fn getOriginalFunction(self: HookManager, fun: anytype) ?@TypeOf(fun) {
        tools.checkIsFnPtr(fun);

        for (self.hooks.items) |item| {
            const original = switch (item.hook_option) {
                .detour => |opt| opt.getOriginalFunction(fun),
                inline else => |opt| opt.getOriginalFunction(fun, self.getPositionFromTarget(@intFromPtr(fun)) orelse return null) catch null,
            };

            if (original) |orig| {
                return orig;
            }
        }

        return null;
    }

    /// Hooks only a single function at the specific index
    pub fn hook(self: *HookManager, comptime index: usize) !void {
        comptime {
            if (index >= self.size) {
                @compileError("Given index out of scope. Is: " ++ std.fmt.fmtIntSizeDec(self.size) ++ " Got: " ++ std.fmt.fmtIntSizeDec(index));
            }
        }

        try self.hooks.items[index].doHook();
    }

    /// Hooks all the registered functions
    pub fn hookAll(self: *HookManager) !void {
        for (self.hooks.items) |*h| {
            try h.doHook();
        }
    }

    /// Restore a hook based on the given hook address
    pub fn restore(self: *HookManager, target_ptr: usize) bool {
        if (self.getIndexFromTarget(target_ptr)) |found_index| {
            var target = self.hooks.swapRemove(found_index);
            target.doRestore();
            return true;
        } else {
            return false;
        }
    }

    /// Adds a new non-vmt based hook
    /// REMARK: Detour is not yet supported.
    pub fn append(
        self: *HookManager,
        method: Method,
    ) !void {
        self.size += 1;
        switch (method) {
            inline .detour => |opt| {
                _ = opt; // autofix
                std.debug.assert(false); // Detour is not yet supported.
                // return self.hooks.append(detour.init(
                //     self.alloc,
                //     opt.source.address,
                //     opt.target.address,
                //     opt.target.len,
                // ));
            },
            inline .vmt => |opt| {
                for (opt.positions, opt.targets) |pos, ptr| {
                    try self.target_to_index.append(Node{
                        .position = pos,
                        .target = ptr,
                    });
                }
                return self.hooks.append(
                    try vmt.init(
                        self.alloc,
                        tools.addressToVtable(opt.object_address),
                        opt.positions,
                        opt.targets,
                    ),
                );
            },
            inline .safe_vmt => |opt| {
                for (opt.positions, opt.targets) |pos, ptr| {
                    try self.target_to_index.append(Node{
                        .position = pos,
                        .target = ptr,
                    });
                }
                return self.hooks.append(
                    try safe_vmt.init(
                        self.alloc,
                        tools.addressToVtable(opt.object_address),
                        opt.positions,
                        opt.targets,
                    ),
                );
            },
        }
    }
};

const t = std.testing;
test "safe vmt" {
    if (@import("builtin").os.tag == .windows) t.refAllDecls(safe_vmt);
}

test "vmt" {
    t.refAllDecls(vmt);
}

// test "detour" {
//     t.refAllDecls(detour);
// }
