.globl _readfile
// _readfile(char *filename, int init_buf_size, int buf_grow_size) -> char *
_readfile:
   push %rbp
   movq %rsp, %rbp
   // (%rsp)(0x8) -> allocated buffer
   // 0x8(%rsp)(0x8) -> fd
   // 0x10(%rsp)(0x4) -> read length
   // 0x14(%rsp)(0x4) -> init_buf_size
   // 0x18(%rsp)(0x4) -> buf_grow_size
   // 0x1c(%rsp)(0x8) -> filename
   subq $0x28, %rsp

   mov %rdi, 0x1c(%rsp)
   mov %esi, 0x14(%rsp)
   mov %edx, 0x18(%rsp)

   mov %rsi, %rdi
   call malloc
   test %rax, %rax
   je _readfile_err

   movq %rax, (%rsp)

   // open the file with syscall 2 = open
   movq $2, %rax
   movq 0x1c(%rsp), %rdi
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
   movl 0x14(%rsp), %edx
   syscall

   // save bytes read
   movl %eax, 0x10(%rsp)

   // check if we need to read more
   cmp 0x14(%rsp), %eax
   je _readfile_alloc_and_read

   jmp _readfile_close

_readfile_alloc_and_read:
   // first allocate buf_grow_size more bytes
   movq (%rsp), %rdi
   movl 0x10(%rsp), %esi
   addl 0x18(%rsp), %esi
   call realloc

   // if failed, bail
   test %rax, %rax
   je _readfile_err_close_free

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

_readfile_close:
   // close the file handle with syscall 3 = close
   movq $3, %rax
   movq 0x8(%rsp), %rdi
   syscall

   test %rax, %rax
   jne _readfile_err_free

_readfile_null:
   movl 0x10(%rsp), %ecx
   movq (%rsp), %rax
   leaq (%rax, %rcx, 1), %rax
   movb $0, (%rax)

   // return the pointer
   movq (%rsp), %rax
_readfile_ret:
   // flop the stack
   addq $0x28, %rsp
   pop %rbp
   ret
_readfile_err_close_free:
   // close the file handle with syscall 3 = close
   movq $3, %rax
   movq 0x8(%rsp), %rdi
   syscall
_readfile_err_free:
   movq (%rsp), %rdi
   call free
_readfile_err:
   movq $0, %rax
   jmp _readfile_ret
