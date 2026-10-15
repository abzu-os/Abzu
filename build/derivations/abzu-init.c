// build/derivations/abzu-init.c
// A minimal, statically-linked init program for Abzu OS.
// Supports both 32-bit (i386) and 64-bit (x86_64) Intel architectures.

// We use 'main' instead of '_start' because on Darwin i386, 
// the C compiler prepends an underscore to C function names.
// So 'main' becomes '_main' in the object file for BOTH i386 and x86_64.
// This allows us to use a single entry point name for the Universal Binary.
void main() {
    const char msg[] = "\n*** ABZU INIT SUCCESSFULLY EXECUTED ***\n";
    
#if defined(__x86_64__)
    // 64-bit Intel (x86_64)
    long len = sizeof(msg) - 1;
    __asm__ volatile (
        "movq $0x2000004, %%rax\n" // Darwin x86_64 SYS_write is 0x2000004
        "movq $1, %%rdi\n"         // file descriptor 1 (stdout)
        "movq %0, %%rsi\n"         // pointer to string
        "movq %1, %%rdx\n"         // length of string
        "syscall\n"
        : 
        : "r" (msg), "r" (len)
        : "rax", "rdi", "rsi", "rdx", "rcx", "r11", "memory"
    );
#elif defined(__i386__)
    // 32-bit Intel (i386)
    int len = sizeof(msg) - 1;
    __asm__ volatile (
        "movl $4, %%eax\n"         // Darwin i386 SYS_write is 4
        "movl $1, %%ebx\n"         // file descriptor 1 (stdout)
        "movl %0, %%ecx\n"         // pointer to string
        "movl %1, %%edx\n"         // length of string
        "int $0x80\n"              // 32-bit syscall interrupt
        : 
        : "r" (msg), "r" (len)
        : "eax", "ebx", "ecx", "edx", "memory"
    );
#endif

    // Safe user-space infinite loop to keep the kernel alive
    while (1) {
        __asm__ volatile ("pause");
    }
}
