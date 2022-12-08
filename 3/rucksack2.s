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
   // (%rsp)(0x8)      -> buffer pointer
   // 0x8(%rsp)(0x8)   -> newline index
   // 0x10(%rsp)(0x4)  -> sum of priorities
   subq $0x14, %rsp

   movl $0, 0x10(%rsp)

find_new_lines:
   xor %rdx, %rdx
   xor %rcx, %rcx
evaluate_lf_loop:
   cmpb $'\n', (%rdi, %rcx, 1)
   je found_new_line
   inc %rcx
   jmp evaluate_lf_loop

found_new_line:
   inc %rdx
   cmpq $3, %rdx
   je found_three_lines
   inc %rcx
   jmp evaluate_lf_loop

found_three_lines:
   // send three lines to _lines_priority
   movq %rdi, (%rsp)
   movq %rcx, 0x8(%rsp)
   movq %rcx, %rsi
   call _lines_priority

   // add priority to sum
   addl %eax, 0x10(%rsp)

   // restore pointer, adjust to next line, scan again
   movq (%rsp), %rdi
   addq 0x8(%rsp), %rdi
   inc %rdi
   cmpb $0, (%rdi)
   jne find_new_lines

   movl 0x10(%rsp), %eax

   addq $0x14, %rsp
   pop %rbp
   ret

.global _lines_priority
// _lines_priority(char *lines, int len) -> int
_lines_priority:
   // %rdi -> string pointer
   // %rsi -> index of 3rd newline
   // %rax -> current string index
   // %rcx -> value of current char
   // %rdx -> string # -> 0, 1, 2
   // %r8  -> overall flags (progressively &'d to)
   // %r9  -> this string's flags

   xor %rax, %rax
   xor %rcx, %rcx
   xor %rdx, %rdx
   xor %r8, %r8
   xor %r9, %r9

left_loop:
   movb (%rdi, %rax, 1), %cl

   cmp $0xa, %cl
   je left_done

   cmp $'Z', %cl
   jle upper_left

   // lowercase
   subb $'a', %cl
   jmp left_flag
upper_left:
   subb $'A', %cl
   addb $26, %cl
left_flag:
   mov $1, %r10
   shl %cl, %r10
   or %r10, %r9
   inc %rax
   jmp left_loop

left_done:
   cmp $0, %rdx
   jne and_flags
   movq %r9, %r8
and_flags:
   and %r9, %r8
   // Move on from 0x0a
   inc %rax
   // Increment string #
   inc %rdx
   // Reset current string flags
   xor %r9, %r9
   cmp %rax, %rsi
   jg left_loop

   // find the only set bit
   mov $0, %rcx
flag_loop:
   mov $1, %rdx
   shl %cl, %rdx
   test %rdx, %r8
   jne match
   inc %cl
   jmp flag_loop

match:
   addb $1, %cl
   mov %rcx, %rax
   ret
