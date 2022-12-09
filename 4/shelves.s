.include "../lib/readfile.s"

.data
filename:
   .string "shelves.real"
result_fmt_str:
   .string "redudant assignments = %d\n"

.text
.globl _start
_start:
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
   // (%rsp)(0x8)     -> buffer pointer
   // 0x8(%rsp)(0x8)  -> newline index
   // 0x10(%rsp)(0x4) -> count of pairs
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
   call _line_redundant

   // add count (0 or 1) to sum
   addl %eax, 0x10(%rsp)

   // restore pointer, adjust to next line, scan again
   movq (%rsp), %rdi
   addq 0x8(%rsp), %rdi
   inc %rdi
   cmpb $0, (%rdi)
   jne find_new_line

   movl 0x10(%rsp), %eax

   addq $0x14, %rsp
   ret

.global _line_redundant
// _line_redundant(char *line, int len) -> int
_line_redundant:
   // (%rsp)(0x8)     -> line
   // 0x8(%rsp)(0x8)  -> current index
   // 0x10(%rsp)(0x4) -> elf1 min
   // 0x14(%rsp)(0x4) -> elf1 max
   // 0x18(%rsp)(0x4) -> elf2 min
   // 0x1c(%rsp)(0x4) -> elf2 max

   subq $0x20, %rsp

   movq %rdi, (%rsp)
   movb $'-', %sil
   call _find_char_and_atoi
   movl %eax, 0x10(%rsp)
   movq (%rsp), %rdi
   addq %rcx, %rdi

   movq %rdi, (%rsp)
   movb $',', %sil
   call _find_char_and_atoi
   movl %eax, 0x14(%rsp)
   movq (%rsp), %rdi
   addq %rcx, %rdi

   movq %rdi, (%rsp)
   movb $'-', %sil
   call _find_char_and_atoi
   movl %eax, 0x18(%rsp)
   movq (%rsp), %rdi
   addq %rcx, %rdi

   movq %rdi, (%rsp)
   movb $'\n', %sil
   call _find_char_and_atoi
   movl %eax, 0x1c(%rsp)
   movq (%rsp), %rdi
   addq %rcx, %rdi

   movl 0x10(%rsp), %r8d
   movl 0x14(%rsp), %r9d
   movl 0x18(%rsp), %r10d
   movl 0x1c(%rsp), %r11d

   xor %rax, %rax

   cmp %r8d, %r10d
   // mins equal means one always contains the other
   je yep
   jg left_nope

   // left min > right min, left max must be <= right max
   cmp %r9d, %r11d
   jge yep
   jmp done
left_nope:
   // left min < right min, right max must be <= left max
   cmp %r9d, %r11d
   jg done

yep:
   mov $1, %rax
done:
   addq $0x20, %rsp
   ret

// call with %rdi=string, %sil=char returns int in %eax, updated counter in %rcx
_find_char_and_atoi:
   // (%rsp) -> counter
   subq $8, %rsp

   xor %rcx, %rcx
find_char_loop:
   cmpb %sil, (%rdi, %rcx, 1)
   je char_found
   inc %rcx
   jmp find_char_loop

char_found:
   movb $0, (%rdi, %rcx, 1)
   inc %rcx
   movq %rcx, (%rsp)

   call atoi
   movq (%rsp), %rcx

   addq $8, %rsp
   ret
