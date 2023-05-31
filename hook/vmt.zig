const std = @import("std");
const builtin = @import("builtin");
const win = std.os.windows;
const lin = std.os.linux;

const isFuncPtr = @import("fn_ptr/func_ptr.zig").checkIfFnPtr;

const vtable_tools = @import("vtable_tools.zig");

const interface = @import("interface.zig");
const ho = @import("hooking_option.zig");

const Address = union(enum) {
    win_addr: win.LPVOID,
    lin_addr: [*]const u8,

    pub fn init(ptr_type: vtable_tools.Vtable) Address {
        return switch (builtin.os.tag) {
            .windows => Address{
                .win_addr = @ptrCast(win.LPVOID, ptr_type),
            },
            .linux => Address{
                .lin_addr = @ptrCast([*]const u8, ptr_type),
            },
            else => |a| @panic("The OS '" ++ @tagName(a) ++ "' is not supported."),
        };
    }
};

const Flags = enum {
    read,
    readwrite,
    execute,
};

inline fn getFlags(comptime flag: Flags) usize {
    comptime {
        const is_linux = builtin.os.tag == .linux;
        return switch (flag) {
            inline .read => if (is_linux) lin.PROT.READ else win.PAGE_READONLY,
            inline .readwrite => if (is_linux) lin.PROT.READ | lin.PROT.WRITE else win.PAGE_READWRITE,
            inline .execute => if (is_linux) lin.PROT.EXEC else win.PAGE_EXECUTE,
        };
    }
}

pub fn setNewProtect(address: Address, size: usize, new_protect: usize) anyerror!?usize {
    const len = if (size == 0) @sizeOf(usize) else size * @sizeOf(usize);
    switch (address) {
        inline .win_addr => |addr| {
            var old: win.DWORD = undefined;
            try win.VirtualProtect(addr, @as(win.SIZE_T, len), @intCast(win.DWORD, new_protect), &old);
            return @as(usize, old);
        },
        inline .lin_addr => |addr| {
            if (lin.mprotect(addr, len, new_protect) != 0) return error.LinuxMProtectFailed;
            return null;
        },
    }
}

fn hook(option: *ho.HookingOption) anyerror!void {
    var unwrapped = switch (option.*) {
        .vmt_option => |*opt| opt,
    };

    const ptr = Address.init(unwrapped.base.*);
    const new_flags = getFlags(Flags.readwrite);

    for (unwrapped.index_map) |*map| {
        const old = try setNewProtect(ptr, map.position, new_flags) orelse getFlags(Flags.read);
        defer _ = setNewProtect(ptr, map.position, old) catch {};
        map.restore = unwrapped.base.*[map.position];
        unwrapped.base.*[map.position] = map.target;
    }
}

fn restore(option: *ho.HookingOption) void {
    var unwrapped = switch (option.*) {
        .vmt_option => |*opt| opt,
    };

    for (unwrapped.index_map) |map| {
        unwrapped.base.*[map.position] = map.restore.?;
        hook(option) catch @panic("Restoring the original vtable failed.");
    }
}

pub fn init(base_class: vtable_tools.AbstractClass, comptime positions: []const usize, targets: []const usize) !interface.Hook {
    var opt = ho.VmtOption.init(base_class, positions, targets);
    var self = interface.Hook.init(&hook, &restore, ho.HookingOption{ .vmt_option = opt });

    try self.do_hook();
    return self;
}
