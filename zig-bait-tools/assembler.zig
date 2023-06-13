// x86_64
// 0:  48 b8 37 13 37 13 37    movabs rax,0x1337133713371337
// 7:  13 37 13
// a:  ff e0                   jmp    rax//

// x86
// 0:  b8 37 13 37 13          mov    eax,0x13371337
// 5:  ff e0                   jmp    eax

// Just some internally used collection of common opcodes
pub const Opcodes = enum(u8) {
    mov = 0x48,
    jmp = 0xff,
};

pub const Register = enum(u8) {
    absax = 0xB8,
    jmpax = 0xE0,
};

pub const ptrSize = @sizeOf(usize);
pub inline fn addressToBytes(target: usize) [ptrSize]8 {
    var arr: [ptrSize]u8 = undefined;
    var current: usize = 0;
    while (current < arr.len) : (current += 1) {
        const shifter = @intCast(u6, current * ptrSize);
        arr[current] = @truncate(u8, target >> shifter);
    }

    return arr;
}
