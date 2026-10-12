// build/derivations/abzu-init.c
// A minimal, statically-linked init program for Abzu OS.
// Uses raw x86_64 Darwin syscalls to avoid any dependency on libSystem.B.dylib.

void _start() {
    const char msg[] = "\n*** ABZU INIT SUCCESSFULLY EXECUTED ***\n";
    long len = sizeof(msg) - 1;
    
    // x86_64 Darwin syscall: SYS_write (4)
    // rax = 4, rdi = 1 (stdout), rsi = msg, rdx = len
    __asm__ volatile (
        "movq $4, %%rax\n"
        "movq $1, %%rdi\n"
        "movq %0, %%rsi\n"
        "movq %1, %%rdx\n"
        "syscall\n"
        : 
        : "r" (msg), "r" (len)
        : "rax", "rdi", "rsi", "rdx", "rcx", "r11", "memory"
    );

    // Infinite loop to keep the kernel alive so we can read the screen
    while (1) {
        __asm__ volatile ("hlt");
    }
}
