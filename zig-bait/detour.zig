const std = @import("std");
const builtin = @import("builtin");
const win = std.os.windows;
const lin = std.os.linux;

const tools = @import("zig-bait-tools");
const interface = @import("interface.zig");
const option = @import("option/option.zig");

const detour = @import("option/detour.zig");

const Allocator = std.mem.Allocator;

fn generateShellcode(target_address: usize, comptime total_buffer: usize) [total_buffer]u8 {
    var shellcode: [total_buffer]u8 = undefined;

    comptime var next = 0;

    // movabs [e|r]ax, target_address
    if (detour.bitHigh == 1) {
        shellcode[next] = @intFromEnum(tools.Opcodes.mov);
        next += 1;
    }

    shellcode[next] = @intFromEnum(tools.Register.absax);
    next += 1;

    inline for (tools.addressToBytes(target_address)) |byte| {
        shellcode[next] = byte;
        next += 1;
    }

    // jmp rax
    shellcode[next] = @intFromEnum(tools.Opcodes.jmp);
    next += 1;
    shellcode[next] = @intFromEnum(tools.Register.jmpax);

    while (next < total_buffer) : (next += 1) {
        shellcode[next] = @intFromEnum(tools.Opcodes.nop);
    }

    return shellcode;
}

fn hook(opt: *option.detour.Option) anyerror!void {
    if (detour.requiredSize > opt.total_size) {
        @compileError("Total buffer size is too small.");
    }

    const opcodes = @as(*align(1) [opt.total_size]u8, @ptrFromInt(opt.victim));
    const shellcode = generateShellcode(opt.target);

    opt.ops = try detour.ExtractedOperations.init(opt.alloc, detour.requiredSize);

    const ptr = tools.Address.init(opcodes);
    const new_flags = tools.getFlags(tools.Flags.readwrite);
    const old = try tools.setNewProtect(ptr, opt.total_size, new_flags) orelse tools.getFlags(tools.Flags.read);
    defer _ = tools.setNewProtect(ptr, opt.total_size, old) catch {};
    for (opcodes.*, shellcode, 0..) |byte, sc, i| {
        opt.ops.?.extracted[i] = byte;
        const b = @constCast(&byte);
        b.* = sc;
    }
}

fn restore(opt: *option.detour.Option) void {
    const original_bytes = @as(*align(1) [opt.total_size]u8, @ptrFromInt(opt.victim));
    for (opt.ops.?.extracted, 0..) |byte, i| {
        original_bytes.*[i] = byte;
    }
}

pub fn init(alloc: Allocator, target_ptr: anytype, victim_address: usize, total_size: usize) interface.Hook {
    tools.checkIsFnPtr(target_ptr);

    const opt = option.detour.Option.init(alloc, target_ptr, victim_address, total_size, &hook, &restore);
    const self = interface.Hook.init(option.Option{ .detour = opt });
    return self;
}
