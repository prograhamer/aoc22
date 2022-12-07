.globl _readfile
// _readfile(char *filename, int init_buf_size, int buf_grow_size) -> char *
_readfile:
   push %rbp
   // %rsp(q) -> allocated buffer
   // %rsp+8(q) -> fd
   // %rsp+16(w) -> read length
   // %rsp+20(w) -> init_buf_size
   // %rsp+24(w) -> buf_grow_size
   // %rsp+28(q) -> filename
   subq $36, %rsp
   movq %rsp, %rbp

   mov %rdi, 28(%rsp)
   mov %esi, 20(%rsp)
   mov %edx, 24(%rsp)

   mov %rsi, %rdi
   call malloc

   test %rax, %rax
   je _readfile_err

   movq %rax, (%rsp)

   // open the file with syscall 2 = open
   movq $2, %rax
   movq 28(%rsp), %rdi
   // 0 flags
   xor %rsi, %rsi
   // 0 mode
   xor %rdx, %rdx
   syscall

   cmp $0, %rax
   jle _readfile_err

   movq %rax, 0x8(%rsp)

   // read the file with syscall 0 = read
   movq $0, %rax
   movq 0x8(%rsp), %rdi
   movq (%rsp), %rsi
   movl 20(%rsp), %edx
   syscall

   // save bytes read
   movl %eax, 0x10(%rsp)

   // check if we need to read more
   cmp 20(%rsp), %eax
   je _readfile_alloc_and_read

   // close the file handle with syscall 3 = close
   movq $3, %rax
   movq 0x8(%rsp), %rdi
   syscall

   test %rax, %rax
   jne _readfile_err

   je _readfile_null

_readfile_alloc_and_read:
   // first allocate buf_grow_size more bytes
   movq (%rsp), %rdi
   movl 0x10(%rsp), %esi
   addl 24(%rsp), %esi
   call realloc

   // if failed, bail
   test %rax, %rax
   je _readfile_err

   // save the new pointer
   movq %rax, (%rsp)

   // read into base pointer, plus read bytes offset
   movq $0, %rax
   movq 0x8(%rsp), %rdi
   movq (%rsp), %rsi
   movl 0x10(%rsp), %ecx
   leaq (%rsi, %rcx, 1), %rsi
   movl 24(%rsp), %edx
   syscall

   // add to read bytes
   addl %eax, 0x10(%rsp)

   // if there's more to read, keep going
   cmp 24(%rsp), %eax
   je _readfile_alloc_and_read

_readfile_null:
   movl 0x10(%rsp), %ecx
   movq (%rsp), %rax
   leaq (%rax, %rcx, 1), %rax
   movb $0, (%rax)

_readfile_ret:
   // return the pointer
   movq (%rsp), %rax

   // flop the stack
   addq $36, %rsp
   pop %rbp
   ret
_readfile_err:
   movq $-1, %rax
   jmp _readfile_ret
