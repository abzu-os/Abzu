// build/derivations/abzu-init.c
// A minimal, statically-linked init program for Abzu OS.
// Supports both 32-bit (i386) and 64-bit (x86_64) Intel architectures.
// Uses raw Darwin syscalls to avoid any dependency on libSystem.B.dylib.

void _start() {
    const char msg[] = "\n*** ABZU INIT SUCCESSFULLY EXECUTED ***\n";
    
#if defined(__x86_64__)
    // 64-bit Intel (x86_64)
    long len = sizeof(msg) - 1;
    __asm__ volatile (
        "movq $4, %%rax\n"      // syscall number for SYS_write
        "movq $1, %%rdi\n"      // file descriptor 1 (stdout)
        "movq %0, %%rsi\n"      // pointer to string
        "movq %1, %%rdx\n"      // length of string
        "syscall\n"
        : 
        : "r" (msg), "r" (len)
        : "rax", "rdi", "rsi", "rdx", "rcx", "r11", "memory"
    );
#elif defined(__i386__)
    // 32-bit Intel (i386)
    int len = sizeof(msg) - 1;
    __asm__ volatile (
        "movl $4, %%eax\n"      // syscall number for SYS_write
        "movl $1, %%ebx\n"      // file descriptor 1 (stdout)
        "movl %0, %%ecx\n"      // pointer to string
        "movl %1, %%edx\n"      // length of string
        "int $0x80\n"           // 32-bit syscall interrupt
        : 
        : "r" (msg), "r" (len)
        : "eax", "ebx", "ecx", "edx", "memory"
    );
#endif

    // CRITICAL: Keep the kernel alive to prevent the "initproc exited" panic.
    // We CANNOT use 'hlt' here. 'hlt' is a Ring 0 (privileged) instruction.
    // Since init runs in Ring 3 (user space), 'hlt' would cause a kernel panic.
    // 'pause' is a safe, user-space no-op that prevents the CPU from spinning too hot.
    while (1) {
        __asm__ volatile ("pause");
    }
}
