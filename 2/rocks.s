.data
filename:
   .string "rocks.real"
init_buf_size:
   .long 100
buf_grow_size:
   .long 100
result_fmt_str:
   .string "total strategy value = %d\n"

.text
.globl _start
_start:
   movq %rsp, %rbp
   // %rsp -> file contents buffer
   subq $8, %rsp

   call _readfile

   cmpq $-1, %rax
   je err

   movq %rax, (%rsp)

   movq %rax, %rdi
   call _evaluate

   movq $result_fmt_str, %rdi
   movq %rax, %rsi
   xor %rax, %rax
   call printf

   movq (%rsp), %rdi
   call free

   movq $60, %rax
   movq $0, %rdi
   syscall

err:
   movq $60, %rax
   movq $1, %rdi
   syscall

.globl _readfile
// _readfile() -> char *
_readfile:
   push %rbp
   // %rsp -> allocated buffer
   // %rsp+8 -> fd
   // %rsp+16 -> read length
   subq $20, %rsp
   movq %rsp, %rbp

   xor %rdi, %rdi
   movl init_buf_size, %edi
   call malloc

   test %rax, %rax
   je _readfile_err

   movq %rax, (%rsp)

   // open the file with syscall 2 = open
   movq $2, %rax
   movq $filename, %rdi
   movq $filename, %rdi
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
   xor %rdx, %rdx
   movl init_buf_size, %edx
   syscall

   // save bytes read
   movl %eax, 0x10(%rsp)

   // check if we need to read more
   cmp init_buf_size, %eax
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
   xor %rsi, %rsi
   movl 0x10(%rsp), %esi
   addl buf_grow_size, %esi
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
   xor %rcx, %rcx
   movl 0x10(%rsp), %ecx
   leaq (%rsi, %rcx, 1), %rsi
   xor %rdx, %rdx
   movl buf_grow_size, %edx
   syscall

   // add to read bytes
   addl %eax, 0x10(%rsp)

   // if there's more to read, keep going
   cmp buf_grow_size, %eax
   je _readfile_alloc_and_read

_readfile_null:
   xor %rcx, %rcx
   movl 0x10(%rsp), %ecx
   movq (%rsp), %rax
   leaq (%rax, %rcx, 1), %rax
   movb $0, (%rax)

_readfile_ret:
   // return the pointer
   movq (%rsp), %rax

   // flop the stack
   addq $20, %rsp
   pop %rbp
   ret
_readfile_err:
   movq $-1, %rax
   jmp _readfile_ret

.globl _evaluate
// _evaluate(buf) -> int
_evaluate:
   push %rbp
   // %rsp(q): buffer position pointer
   // %rsp+8(l): strategy value
   subq $12, %rsp
   movq %rsp, %rbp

   // initialize buffer pointer and strategy value
   movq %rdi, (%rsp)
   movl $0, 8(%rsp)

   // move through buffer in steps of four evaluating moves
   // buffer[0] = their move, buffer[2] = our move, odd = 0x20, 0x0a
_evaluate_again:
   movq (%rsp), %rbx
   xor %rdi, %rdi
   xor %rsi, %rsi
   movb (%rbx), %dil
   movb 2(%rbx), %sil

   call _evaluate_round

   addl %eax, 8(%rsp)

   addq $4, (%rsp)
   movq (%rsp), %rbx
   cmpb $0, (%rbx)
   jne _evaluate_again

   xor %rax, %rax
   movl 8(%rsp), %eax

   addq $12, %rsp
   pop %rbp
   ret

.globl _evaluate_round
// _evaluate_round(char them, char us) -> int
_evaluate_round:
   movq $0, %rax

   movb %sil, %dl
   subb $'W', %dl
   addb %dl, %al

   movb %sil, %dl
   subb $23, %dl
   cmpb %dl, %dil
   je draw

   cmpb $'A', %dil
   je them_rock
   cmpb $'B', %dil
   je them_paper

   // know they played scissors
   cmpb $'X', %sil
   je win
   ret

them_rock:
   cmpb $'Y', %sil
   je win
   ret

them_paper:
   cmpb $'Z', %sil
   je win
   ret

win:
   addb $6, %al
   ret
draw:
   addb $3, %al
   ret
