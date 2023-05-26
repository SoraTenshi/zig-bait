const std = @import("std");
const builtin = @import("builtin");
const win = std.os.windows;
const lin = std.os.linux;

const isFuncPtr = @import("fn_ptr/func_ptr.zig").checkIfFnPtr;

const interface = @import("interface.zig");
const ho = @import("hooking_option.zig");

const Vtable = [*]align(1) usize;
pub const AbstractClass = *align(1) Vtable;

pub fn addressToVtable(address: usize) AbstractClass {
    return @intToPtr(AbstractClass, address);
}

const Address = union(enum) {
    win_addr: win.LPVOID,
    lin_addr: [*]const u8,

    pub fn init(ptr_type: Vtable) Address {
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

fn debugPrint(option: *ho.HookingOption, comptime str: []const u8) void {
    const is_debug = switch (option.*) {
        .vmt_option => |opt| opt.debug,
    };

    if (is_debug) {
        std.debug.print("[*] " ++ str ++ "\n", .{});
    }
}

fn debugFmtPrint(option: *ho.HookingOption, comptime fmt: []const u8, args: anytype) void {
    const is_debug = switch (option.*) {
        .vmt_option => |opt| opt.debug,
    };

    if (is_debug) {
        std.debug.print("[*] " ++ fmt ++ "\n", args);
    }
}

/// Query the VMT Region to figure out its size based on Protection levels
/// Expects the vtable to already include the RTTI
fn queryVmtRegion(vtable: Vtable) usize {
    const address = Address.init(vtable).win_addr;
    var size: usize = 1;

    var mba: win.MEMORY_BASIC_INFORMATION = undefined;
    var still_in_range = true;
    while (still_in_range) : (size += 1) {
        _ = win.VirtualQuery(address, &mba, @as(win.SIZE_T, @sizeOf(win.MEMORY_BASIC_INFORMATION))) catch {
            still_in_range = false;
            break;
        };
        still_in_range = ((mba.State == win.MEM_COMMIT) or (mba.Protect & (win.PAGE_GUARD | win.PAGE_NOACCESS) == 0) or (mba.Protect & win.PAGE_EXECUTE | win.PAGE_EXECUTE_READ | win.PAGE_EXECUTE_READWRITE | win.PAGE_EXECUTE_WRITECOPY) != 0);
    }
    std.debug.print("out of vquery loop --- {d} \n", .{size});

    return size - 1;
}

fn hook(option: *ho.HookingOption) anyerror!void {
    if (builtin.os.tag != .windows) {
        @compileError("Safe VMT is only supported on Windows.");
    }

    var unwrapped = switch (option.*) {
        .vmt_option => |*opt| opt,
    };

    unwrapped.restore = @ptrToInt(unwrapped.base.*);

    // include the rtti information
    unwrapped.base.* = @intToPtr(Vtable, @ptrToInt(unwrapped.base.* - 1));

    const vtable_size = queryVmtRegion(unwrapped.base.*);
    var new_vtable = unwrapped.alloc.?.alloc(usize, vtable_size) catch @panic("OOM");

    var current: usize = 0;
    while (current != vtable_size) : (current += 1) {
        if (current + 1 == unwrapped.index) {
            new_vtable[current] = unwrapped.target;
        } else {
            new_vtable[current] = unwrapped.base.*[current];
        }
    }

    unwrapped.created_vtable = new_vtable;
    unwrapped.base.* = @ptrCast(Vtable, new_vtable.ptr);
    unwrapped.base.* += 1;
}

fn restore(option: *ho.HookingOption) void {
    var unwrapped = switch (option.*) {
        .vmt_option => |*opt| opt,
    };

    defer unwrapped.alloc.?.free(unwrapped.created_vtable.?);
    unwrapped.base = @intToPtr(AbstractClass, unwrapped.restore.? + @sizeOf(usize));
}

pub fn init(target: anytype, base_class: AbstractClass, index: usize, alloc: std.mem.Allocator) !interface.Hook {
    isFuncPtr(target);
    var opt = ho.VmtOption.init(base_class, index, @ptrToInt(target), true, alloc);
    var self = interface.Hook.init(&hook, &restore, ho.HookingOption{ .vmt_option = opt });

    try self.do_hook();
    return self;
}
