const std = @import("std");
const win = std.os.windows;
const lin = std.os.linux;

const builtin = @import("builtin");

pub const Address = union(enum) {
    win_addr: win.LPVOID,
    lin_addr: [*]const u8,

    pub fn init(ptr_type: anytype) Address {
        return switch (builtin.os.tag) {
            inline .windows => Address{
                .win_addr = @as(win.LPVOID, @ptrCast(ptr_type)),
            },
            inline .linux => Address{
                .lin_addr = @as([*]const u8, @ptrCast(ptr_type)),
            },
            inline else => |a| @panic("The OS '" ++ @tagName(a) ++ "' is not supported."),
        };
    }
};

pub const Flags = enum {
    read,
    readwrite,
    execute,
};

pub inline fn getFlags(comptime flag: Flags) usize {
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
            if (builtin.os.tag != .windows) {
                return error.WrongOs;
            }

            var old: win.DWORD = undefined;
            try win.VirtualProtect(addr, @as(win.SIZE_T, len), @as(win.DWORD, @intCast(new_protect)), &old);
            return @as(usize, old);
        },
        inline .lin_addr => |addr| {
            if (!builtin.os.tag.isBSD() and builtin.os.tag != .linux) {
                return error.WrongOs;
            }

            if (lin.mprotect(addr, len, new_protect) != 0) return error.LinuxMProtectFailed;
            return null;
        },
    }
}
