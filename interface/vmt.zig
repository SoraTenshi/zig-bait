const std = @import("std");
const builtin = @import("builtin");
const win = std.os.windows;
const lin = std.os.linux;

const isFuncPtr = @import("fn_ptr/func_ptr.zig").checkIfFnPtr;

const interface = @import("interface.zig");
const ho = @import("hooking_option.zig");

const Address = union(enum) {
    win_addr: win.LPVOID,
    lin_addr: [*]const u8,

    pub fn init(ptr_type: [*]usize) Address {
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
    switch (address) {
        inline .win_addr => |addr| {
            var old: win.DWORD = undefined;
            try win.VirtualProtect(addr, @as(win.SIZE_T, size), @intCast(win.DWORD, new_protect), &old);
            return @as(usize, old);
        },
        inline .lin_addr => |addr| {
            if (lin.mprotect(addr, size, new_protect) != 0) return error.LinuxMProtectFailed;
            return null;
        },
    }
}

fn hook(option: *ho.HookingOption) anyerror!void {
    var unwrapped = switch (option.*) {
        .vmt_option => |opt| opt,
    };

    const ptr = Address.init(unwrapped.base);

    const new_flags = getFlags(Flags.readwrite);

    const old = try setNewProtect(ptr, unwrapped.index, new_flags);

    var lin_old: usize = undefined;
    if (builtin.os.tag == .linux) {
        lin_old = getFlags(Flags.read);
    }

    unwrapped.restore = unwrapped.base[unwrapped.index];
    unwrapped.base[unwrapped.index] = unwrapped.target;

    _ = try setNewProtect(ptr, unwrapped.index, old orelse lin_old);
}

fn restore(option: *ho.HookingOption) void {
    var unwrapped = switch (option.*) {
        .vmt_option => |opt| opt,
    };

    unwrapped.base[unwrapped.index] = unwrapped.restore.?;
    hook(option) catch @panic("Restoring the original vtable failed.");
}

pub fn initVmtHook(target: anytype, base: [*]usize, index: usize) !interface.Hook {
    isFuncPtr(target);
    var opt = ho.VmtOption.init(base, index, @ptrToInt(target));
    var self = interface.Hook.init(&hook, &restore, ho.HookingOption{ .vmt_option = opt });

    try self.do_hook();
    return self;
}
