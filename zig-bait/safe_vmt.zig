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
                .win_addr = @as(win.LPVOID, @ptrCast(ptr_type)),
            },
            .linux => Address{
                .lin_addr = @as([*]const u8, @ptrCast(ptr_type)),
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
        const address = Address.init(@as(?tools.Vtable, @ptrFromInt(vtable[size])) orelse {
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

fn hook(opt: *option.safe_vmt.Option) anyerror!void {
    if (builtin.os.tag != .windows) {
        @compileError("Safe VMT is only supported on Windows.");
    }

    opt.safe_orig = @intFromPtr(opt.base.*);

    // include the rtti information
    opt.base.* = opt.base.* - 1;

    const vtable_size = queryVmtRegion(opt.base.*);
    var new_vtable = try opt.alloc.?.allocator().alloc(usize, vtable_size);

    // max = vtable_size
    // index == pos + 1 => swap
    // copy rtti first
    new_vtable[0] = opt.base.*[0];

    var index_storage: usize = 0;
    for (0..vtable_size - 1) |i| {
        new_vtable[i + 1] = opt.base.*[i + 1];
        if (opt.index_map[index_storage].position == i) {
            opt.index_map[index_storage].restore = opt.base.*[i + 1];
            new_vtable[i + 1] = opt.index_map[index_storage].target;
            index_storage += 1;
        }
    }

    opt.created_vtable = new_vtable;
    opt.base.* = @as(tools.Vtable, @ptrCast(new_vtable.ptr));
    opt.base.* += 1;
}

fn restore(opt: *option.safe_vmt.Option) void {
    defer opt.alloc.?.deinit();
    opt.base.* = @as(tools.Vtable, @ptrFromInt(opt.safe_orig.?));
}

pub fn init(alloc: Allocator, base_class: tools.AbstractClass, comptime positions: []const usize, targets: []const usize) interface.Hook {
    var opt = option.safe_vmt.Option.init(alloc, base_class, positions, targets);
    var self = interface.Hook.init(&hook, &restore, option.Option{ .safe_vmt = opt });
    return self;
}
