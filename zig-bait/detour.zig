const std = @import("std");
const builtin = @import("builtin");
const win = std.os.windows;
const lin = std.os.linux;

const tools = @import("zig-bait-tools");
const interface = @import("interface.zig");
const option = @import("option/option.zig");

const Allocator = std.mem.Allocator;

const bitHigh = if (tools.ptrSize == 8) 1 else 0; // 64 bit requires an additional byte
const requiredSize = bitHigh + 3 + tools.ptrSize;

fn generateShellcode(target_address: usize) [requiredSize]u8 {
    var shellcode: [requiredSize]u8 = undefined;

    comptime var next = 0;

    // movabs [e|r]ax, target_address
    if (bitHigh == 1) {
        shellcode[next] = tools.Opcodes.mov;
        next += 1;
    }

    shellcode[next] = tools.Register.absax;
    inline for (tools.addressToBytes(target_address)) |byte| {
        next += 1;
        shellcode[next] = byte;
    }

    // jmp rax
    shellcode[next + 1] = tools.Opcodes.jmp;
    shellcode[next + 2] = tools.Register.jmpax;

    return shellcode;
}

fn hook(opt: *option.Option) anyerror!void {
    var unwrapped = switch (opt.*) {
        .detour => |*o| o,
    };

    var opcodes = @intToPtr(*align(1) [14]u8, unwrapped.victim);
    _ = opcodes;
}

fn restore(opt: *option.Option) void {
    var unwrapped = switch (opt.*) {
        .detour => |*o| o,
    };

    var original_bytes = @intToPtr(*align(1) [14]u8, unwrapped.ops.?.original);
    for (unwrapped.ops.?.extracted, 0..) |byte, i| {
        original_bytes[i] = byte;
    }
}

pub fn init(alloc: Allocator, target_ptr: anytype, victim_address: usize) !interface.Hook {
    if (!std.meta.trait.isPtrTo(@typeInfo(@TypeOf(target_ptr)))(.Fn)) {
        @compileError("Expected target_ptr to be a ptr to a function, got: " ++ @typeName(@TypeOf(target_ptr)));
    }

    var opt = option.detour.DetourOption.init(alloc, target_ptr, victim_address);
    var self = interface.Hook.init(&hook, &restore, option.Option{ .detour = opt });

    try self.do_hook();
    return self;
}
