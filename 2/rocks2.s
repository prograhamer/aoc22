.include "../lib/readfile.s"

.data
filename:
   .string "rocks.test"
result_fmt_str:
   .string "total strategy value = %d\n"

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

   cmpq $0, %rax
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

   movl 8(%rsp), %eax

   addq $12, %rsp
   pop %rbp
   ret

.globl _evaluate_round
// _evaluate_round(char them, char us) -> int
_evaluate_round:
   movq $0, %rax

   cmpb $'X', %sil
   je must_lose

   cmpb $'Y', %sil
   je must_draw

   // must win
   cmpb $'A', %dil
   je us_paper
   cmpb $'B', %dil
   je us_scissors
   jmp us_rock

must_lose:
   cmpb $'A', %dil
   je us_scissors
   cmpb $'B', %dil
   je us_rock
   jmp us_paper

must_draw:
   cmpb $'A', %dil
   je us_rock
   cmpb $'B', %dil
   je us_paper
   jmp us_scissors

us_rock:
   movb $'X', %sil
   jmp match_score
us_paper:
   movb $'Y', %sil
   jmp match_score
us_scissors:
   movb $'Z', %sil
   jmp match_score

match_score:
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
