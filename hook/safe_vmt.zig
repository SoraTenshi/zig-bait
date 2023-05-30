const std = @import("std");
const builtin = @import("builtin");
const win = std.os.windows;
const lin = std.os.linux;

const fn_ptr = @import("fn_ptr/func_ptr.zig");
const isFuncPtr = fn_ptr.checkIfFnPtr;

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

/// Query the VMT Region to figure out its size based on Protection levels
/// Expects the vtable to already include the RTTI
fn queryVmtRegion(vtable: Vtable) usize {
    var size: usize = 1;

    var mba: win.MEMORY_BASIC_INFORMATION = undefined;
    var still_in_range = true;
    while (still_in_range) : (size += 1) {
        const address = Address.init(@intToPtr(?Vtable, vtable[size]) orelse {
            still_in_range = false;
            break;
        }).win_addr;
        _ = win.VirtualQuery(address, &mba, @as(win.SIZE_T, @sizeOf(win.MEMORY_BASIC_INFORMATION))) catch {
            still_in_range = false;
            break;
        };
        still_in_range = ((mba.State == win.MEM_COMMIT) or (mba.Protect & (win.PAGE_GUARD | win.PAGE_NOACCESS) == 0) or (mba.Protect & win.PAGE_EXECUTE | win.PAGE_EXECUTE_READ | win.PAGE_EXECUTE_READWRITE | win.PAGE_EXECUTE_WRITECOPY) != 0);
    }

    return size;
}

fn hook(option: *ho.HookingOption) anyerror!void {
    if (builtin.os.tag != .windows) {
        @compileError("Safe VMT is only supported on Windows.");
    }

    var unwrapped = switch (option.*) {
        .vmt_option => |*opt| opt,
    };

    unwrapped.safe_orig = @ptrToInt(unwrapped.base.*);

    // include the rtti information
    unwrapped.base.* = unwrapped.base.* - 1;

    const vtable_size = queryVmtRegion(unwrapped.base.*);
    var new_vtable = unwrapped.alloc.?.allocator().alloc(usize, vtable_size) catch @panic("OOM");

    var current: usize = 0;
    outer: while (current != vtable_size) : (current += 1) {
        for (unwrapped.index_map) |*map| {
            if (map.position + 1 == current) {
                map.restore = unwrapped.base.*[current];
                new_vtable[current] = map.target;
                continue :outer;
            }
        }
        new_vtable[current] = unwrapped.base.*[current];
    }

    unwrapped.created_vtable = new_vtable;
    unwrapped.base.* = @ptrCast(Vtable, new_vtable.ptr);
    unwrapped.base.* += 1;
}

fn restore(option: *ho.HookingOption) void {
    var unwrapped = switch (option.*) {
        .vmt_option => |*opt| opt,
    };

    defer unwrapped.alloc.?.deinit();
    unwrapped.base = @intToPtr(AbstractClass, unwrapped.safe_orig.? + @sizeOf(usize));
}

pub fn init(base_class: AbstractClass, comptime positions: []const usize, targets: []const usize, alloc: std.mem.Allocator) !interface.Hook {
    var opt = ho.VmtOption.initSafe(base_class, positions, targets, alloc);
    var self = interface.Hook.init(&hook, &restore, ho.HookingOption{ .vmt_option = opt });
    try self.do_hook();
    return self;
}
