const std = @import("std");

const tools = @import("zig-bait-tools");

const Allocator = std.mem.Allocator;

pub const bitHigh = if (tools.ptrSize == 8) 1 else 0; // 64 bit requires an additional byte
pub const requiredSize = bitHigh + 3 + tools.ptrSize;

/// The information of the overriden instructions
pub const ExtractedOperations = struct {
    // The stored prologue
    extracted: []u8,
    // The address where the stored prologue is located
    address: usize,

    pub fn init(alloc: Allocator, shellcode_size: usize) !ExtractedOperations {
        const extracted = try alloc.alloc(u8, shellcode_size);
        return ExtractedOperations{
            .extracted = extracted,
            .address = @ptrToInt(extracted.ptr),
        };
    }
};

pub const HookFunc = tools.HookFunctionType(Option);
pub const RestoreFunc = tools.RestoreFunctionType(Option);

pub const Option = struct {
    /// The stored operations
    ops: ?ExtractedOperations,
    /// The address to the targeted function
    target: usize,
    /// The address of the victim function
    victim: usize,
    /// address to the after-jump location
    after_jump: usize,
    /// alloc
    alloc: Allocator,
    /// The hook function
    hook: HookFunc,
    /// The restore function
    restore: RestoreFunc,

    pub fn init(
        alloc: Allocator,
        target_ptr: anytype,
        victim_address: usize,
        hook: HookFunc,
        restore: RestoreFunc,
    ) Option {
        return Option{
            .ops = null,
            .target = @ptrToInt(target_ptr),
            .victim = victim_address,
            .after_jump = victim_address + requiredSize,
            .alloc = alloc,
            .hook = hook,
            .restore = restore,
        };
    }

    pub fn getOriginalFunction(self: Option, original_func: anytype) @TypeOf(original_func) {
        return @intToPtr(@TypeOf(original_func), self.after_jump);
    }

    pub fn deinit(self: *Option) void {
        self.alloc.free(self.op.extracted);
    }
};
