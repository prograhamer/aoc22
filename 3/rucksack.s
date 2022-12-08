.include "../lib/readfile.s"

.data
filename:
   .string "rucksack.test"
result_fmt_str:
   .string "sum of priorities = %d\n"

.text
.globl _start
_start:
   movq %rsp, %rbp
   // %rsp -> file contents buffer
   subq $8, %rsp

   movq $filename, %rdi
   movq $1024, %rsi
   movq $2048, %rdx
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

.globl _evaluate
// _evaluate(buf) -> int
_evaluate:
   // find newline
   push %rbp
   // (%rsp)(0x8)     -> buffer pointer
   // 0x8(%rsp)(0x8)  -> newline index
   // 0x10(%rsp)(0x4) -> sum of priorities
   subq $0x14, %rsp

   movl $0, 0x10(%rsp)

find_new_line:
   xor %rcx, %rcx
evaluate_lf_loop:
   cmpb $'\n', (%rdi, %rcx, 1)
   je found_new_line
   inc %rcx
   jmp evaluate_lf_loop

found_new_line:
   movq %rdi, (%rsp)
   movq %rcx, 0x8(%rsp)
   movq %rcx, %rsi
   call _line_priority

   // add priority to sum
   addl %eax, 0x10(%rsp)

   // restore pointer, adjust to next line, scan again
   movq (%rsp), %rdi
   addq 0x8(%rsp), %rdi
   inc %rdi
   cmpb $0, (%rdi)
   jne find_new_line

   movl 0x10(%rsp), %eax

   addq $0x14, %rsp
   pop %rbp
   ret

.global _line_priority
// _line_priority(char *line, int len) -> int
_line_priority:
   push %rbp
   // (%rsp)(0x34)     -> character flags left
   // 0x34(%rsp)(0x34) -> character flags right
   // 0x68(%rsp)(0x8)  -> line
   // 0x70(%rsp)(0x8)  -> len
   subq $0x78, %rsp

   movq %rdi, 0x68(%rsp)
   movq %rsi, 0x70(%rsp)

   // zero flags
   movq %rsp, %rdi
   movq $0, %rsi
   movq $0x68, %rdx
   call memset

   // populate left flags
   // pointer to start of line
   movq 0x68(%rsp), %rbx
   // index of newline
   movq 0x70(%rsp), %rcx
   movq %rcx, %rdx
   // index of midpoint
   sar $1, %rdx

   // index of current char
   xor %rax, %rax
   xor %r8, %r8
left_loop:
   movb (%rbx, %rax, 1), %r8b
   cmp $'Z', %r8b
   jle upper_left

   // lowercase
   subb $'a', %r8b
   jmp left_flag
upper_left:
   subb $'A', %r8b
   addb $26, %r8b
left_flag:
   movb $1, (%rsp, %r8, 1)
   inc %rax
   cmp %rax, %rdx
   jne left_loop

   // populate right flags
right_loop:
   movb (%rbx, %rax, 1), %r8b
   cmp $'Z', %r8b
   jle upper_right

   // lowercase
   subb $'a', %r8b
   jmp right_flag
upper_right:
   subb $'A', %r8b
   addb $26, %r8b
right_flag:
   movb $1, 0x34(%rsp, %r8, 1)
   inc %rax
   cmp %rax, %rcx
   jne right_loop

   // now loop through both sets of flags looking for where right[i] == left[i]
   xor %rax, %rax
flag_loop:
   movb (%rsp, %rax, 1), %r8b
   mov 0x34(%rsp, %rax, 1), %r9b
   // need a 1, not a zero
   test %r8b, %r8b
   je next

   // need a match
   cmp %r8b, %r9b
   je match
next:
   inc %rax
   jmp flag_loop

match:
   addq $1, %rax

done:
   addq $0x78, %rsp
   pop %rbp
   ret
