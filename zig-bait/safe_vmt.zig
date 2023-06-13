const std = @import("std");
const builtin = @import("builtin");
const win = std.os.windows;
const lin = std.os.linux;

const tools = @import("zig-bait-tools");
const interface = @import("interface.zig");
const option = @import("option/option.zig");

const Allocator = std.mem.Allocator;

const Address = union(enum) {
    win_addr: win.LPVOID,
    lin_addr: [*]const u8,

    pub fn init(ptr_type: tools.Vtable) Address {
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
fn queryVmtRegion(vtable: tools.Vtable) usize {
    var size: usize = 1;

    var mba: win.MEMORY_BASIC_INFORMATION = undefined;
    var still_in_range = true;
    while (still_in_range) : (size += 1) {
        const address = Address.init(@intToPtr(?tools.Vtable, vtable[size]) orelse {
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

fn hook(opt: *option.Option) anyerror!void {
    if (builtin.os.tag != .windows) {
        @compileError("Safe VMT is only supported on Windows.");
    }

    var unwrapped = switch (opt.*) {
        .safe_vmt => |*o| o,
        else => return error.WrongOption,
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
    unwrapped.base.* = @ptrCast(tools.Vtable, new_vtable.ptr);
    unwrapped.base.* += 1;
}

fn restore(opt: *option.Option) void {
    var unwrapped = switch (opt.*) {
        .safe_vmt => |*o| o,
        else => return error.WrongOption,
    };

    defer unwrapped.alloc.?.deinit();
    unwrapped.base.* = @intToPtr(tools.Vtable, unwrapped.safe_orig.?);
}

pub fn init(alloc: Allocator, base_class: tools.AbstractClass, comptime positions: []const usize, targets: []const usize) !interface.Hook {
    var opt = option.safe_vmt.SafeVmtOption.initSafe(alloc, base_class, positions, targets);
    var self = interface.Hook.init(&hook, &restore, option.Option{ .safe_vmt = opt });
    try self.do_hook();
    return self;
}
