.include "../lib/readfile.s"

.text
.globl main
main:
	push %rbp
	mov %rsp, %rbp
	// (%rsp)(0x8) -> file contents buffer
	subq $0x10, %rsp

	cmp $2, %rdi
	jne invalid_args

	movq 0x8(%rsi), %rdi
	movq $1024, %rsi
	movq $2048, %rdx
	call _readfile

	cmpq $0, %rax
	je err

	movq %rax, (%rsp)

	movq %rax, %rdi
	call process_part_1
	cmp $-1, %rax
	je err

	leaq result_1_fmt_str(%rip), %rdi
	movq %rax, %rsi
	xor %rax, %rax
	call printf

	movq (%rsp), %rdi
	call free

	movq $60, %rax
	movq $0, %rdi
	syscall

invalid_args:
	leaq invalid_args_str(%rip), %rdi
	call puts
err:
	leaq error_str(%rip), %rdi
	call puts

	movq $60, %rax
	movq $1, %rdi
	syscall

invalid_args_str:
	.string "invalid arguments, expected input filename"
error_str:
	.string "an error occurred :("
result_1_fmt_str:
	.string "sum of signal strengths = %d\n"
point_fmt:
	.string "%c"
point_fmt_nl:
	.string "%c\n"

process_part_1:
	push %rbp
	mov %rsp, %rbp

	call sum_signal_strengths

	mov %rbp, %rsp
	pop %rbp
	ret

// sum_signal_strengths(char *input) -> int32
sum_signal_strengths:
	push %rbp
	push %rbx
	push %r12
	push %r13
	push %r14
	mov %rsp, %rbp

	// %rbx -> current position in input
	movq %rdi, %rbx
	// %r12d -> current cycle number
	movl $1, %r12d
	// %r13d -> current register value
	movl $1, %r13d
	// %r14d -> signal strength sum
	xor %r14d, %r14d

sum_signal_strengths_line_loop:
	movl %r12d, %edi
	movl %r13d, %esi
	call check_signal_strength
	addl %eax, %r14d

	movl %r12d, %edi
	movl %r13d, %esi
	call output_point

	// addx
	cmpl $0x78646461, (%rbx)
	je sum_signal_strengths_add

	// noop
	cmpl $0x706f6f6e, (%rbx)
	jne sum_signal_strengths_err

	incl %r12d
	jmp sum_signal_strengths_next_line

sum_signal_strengths_add:
	// cycle 1
	incl %r12d

	movl %r12d, %edi
	movl %r13d, %esi
	call check_signal_strength
	addl %eax, %r14d

	movl %r12d, %edi
	movl %r13d, %esi
	call output_point

	// cycle 2 - checked at start of loop
	incl %r12d

	leaq 5(%rbx), %rdi
	call atoi
	test %eax, %eax
	je sum_signal_strengths_err
	addl %eax, %r13d

sum_signal_strengths_next_line:
	incq %rbx
	cmpb $'\n', -1(%rbx)
	jne sum_signal_strengths_next_line
	cmpb $0, (%rbx)
	jne sum_signal_strengths_line_loop

	movl %r14d, %eax
sum_signal_strengths_ret:
	mov %rbp, %rsp
	pop %r14
	pop %r13
	pop %r12
	pop %rbp
	pop %rbp
	ret
sum_signal_strengths_err:
	movq $-1, %rax
	jmp sum_signal_strengths_ret

// check_signal_strength(uint32 current_cycle, uint32 current_value) -> int32
check_signal_strength:
	movl %edi, %eax
	subl $20, %eax
	je check_signal_strength_found
	js check_signal_strength_not_found
	xor %edx, %edx
	movl $40, %ecx
	divl %ecx
	test %edx, %edx
	jne check_signal_strength_not_found
check_signal_strength_found:
	imull %edi, %esi
	movl %esi, %eax
	ret
check_signal_strength_not_found:
	xor %eax, %eax
	ret

// output_point(uint32 current_cycle, uint32 current_value) -> void
output_point:
	push %rbp
	movq %rsp, %rbp

	movl $'.', %r8d
	movl $'#', %r9d

	movl $40, %ecx

	leal -1(%edi), %eax
	xor %edx, %edx
	divl %ecx

	movl %r8d, %edi

	decl %edx
	cmpl %edx, %esi
	cmovel %r9d, %edi
	incl %edx
	cmpl %edx, %esi
	cmovel %r9d, %edi
	incl %edx
	cmpl %edx, %esi
	cmovel %r9d, %edi
	movl %edi, %esi

	leaq point_fmt(%rip), %rdi
	leaq point_fmt_nl(%rip), %r11
	// $39 + $1, because we incremented the value
	cmpl $40, %edx
	cmoveq %r11, %rdi

	xor %rax, %rax
	call printf

	movq %rbp, %rsp
	pop %rbp
	ret
