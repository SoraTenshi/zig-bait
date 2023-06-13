const std = @import("std");
const builtin = @import("builtin");
const win = std.os.windows;
const lin = std.os.linux;

const tools = @import("zig-bait-tools");
const interface = @import("interface.zig");
const option = @import("option/option.zig");

const detour = @import("option/detour.zig");

const Allocator = std.mem.Allocator;

fn generateShellcode(target_address: usize) [detour.requiredSize]u8 {
    var shellcode: [detour.requiredSize]u8 = undefined;

    comptime var next = 0;

    // movabs [e|r]ax, target_address
    if (detour.bitHigh == 1) {
        shellcode[next] = @enumToInt(tools.Opcodes.mov);
        next += 1;
    }

    shellcode[next] = @enumToInt(tools.Register.absax);
    next += 1;

    inline for (tools.addressToBytes(target_address)) |byte| {
        shellcode[next] = byte;
        next += 1;
    }

    // jmp rax
    shellcode[next + 1] = @enumToInt(tools.Opcodes.jmp);
    shellcode[next + 2] = @enumToInt(tools.Register.jmpax);

    return shellcode;
}

fn hook(opt: *option.Option) anyerror!void {
    var unwrapped = switch (opt.*) {
        .detour => |*o| o,
        else => return error.WrongOption,
    };

    var opcodes = @intToPtr(*align(1) [detour.requiredSize]u8, unwrapped.victim);
    const shellcode = generateShellcode(unwrapped.target);
    unwrapped.ops = try detour.ExtractedOperations.init(unwrapped.alloc, detour.requiredSize);

    const ptr = tools.Address.init(opcodes);
    const new_flags = tools.getFlags(tools.Flags.readwrite);
    const old = try tools.setNewProtect(ptr, detour.requiredSize, new_flags) orelse tools.getFlags(tools.Flags.read);
    defer _ = tools.setNewProtect(ptr, detour.requiredSize, old) catch {};
    for (opcodes.*, shellcode, 0..) |byte, sc, i| {
        unwrapped.ops.?.extracted[i] = byte;
        var b = @constCast(&byte);
        b.* = sc;
    }
}

fn restore(opt: *option.Option) void {
    var unwrapped = switch (opt.*) {
        .detour => |*o| o,
        else => unreachable,
    };

    var original_bytes = @intToPtr(*align(1) [detour.requiredSize]u8, unwrapped.ops.?.original);
    for (unwrapped.ops.?.extracted, 0..) |byte, i| {
        original_bytes.*[i] = byte;
    }
}

pub fn init(alloc: Allocator, target_ptr: anytype, victim_address: usize) !interface.Hook {
    tools.checkIsFnPtr(target_ptr);

    var opt = option.detour.DetourOption.init(alloc, target_ptr, victim_address);
    var self = interface.Hook.init(&hook, &restore, option.Option{ .detour = opt });

    try self.do_hook();
    return self;
}
