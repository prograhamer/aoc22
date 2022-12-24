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

process_part_1:
	push %rbp
	mov %rsp, %rbp
	// (%rsp) -> input
	// 0x8(%rsp) -> int32 cycles[8]
	subq $30, %rsp

	movq %rdi, (%rsp)

	movl $20, 0x8(%rsp)
	movl $60, 0xc(%rsp)
	movl $100, 0x10(%rsp)
	movl $140, 0x14(%rsp)
	movl $180, 0x18(%rsp)
	movl $220, 0x1c(%rsp)
	movl $0, 0x20(%rsp)

	leaq 0x8(%rsp), %rsi
	call sum_signal_strengths

	mov %rbp, %rsp
	pop %rbp
	ret

// sum_signal_strengths(char *input, int32 *cycle_numbers) -> int32
sum_signal_strengths:
	push %rbp
	push %rbx
	push %r12
	push %r13
	push %r14
	push %r15
	mov %rsp, %rbp
	// (%rsp)(0x8) -> int32 *cycle_numbers
	subq $0x8, %rsp

	movq %rsi, (%rsp)

	// %rbx -> current position in input
	movq %rdi, %rbx
	// %r12d -> current cycle number
	movl $1, %r12d
	// %r13d -> current register value
	movl $1, %r13d
	// %r14d -> signal strength sum
	xor %r14d, %r14d

sum_signal_strengths_line_loop:
	movq (%rsp), %rdi
	movl %r12d, %esi
	movl %r13d, %edx
	call check_signal_strength
	addl %eax, %r14d

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

	movq (%rsp), %rdi
	movl %r12d, %esi
	movl %r13d, %edx
	call check_signal_strength
	addl %eax, %r14d

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
	pop %r15
	pop %r14
	pop %r13
	pop %r12
	pop %rbp
	pop %rbp
	ret
sum_signal_strengths_err:
	movq $-1, %rax
	jmp sum_signal_strengths_ret

// check_signal_strength(uint32 *cycle_numbers, uint32 current_cycle, uint32 current_value) -> int32
check_signal_strength:
	xor %rcx, %rcx
check_signal_strength_loop:
	movl (%rdi, %rcx, 4), %eax
	cmpl $0, %eax
	je check_signal_strength_not_found
	cmpl %esi, %eax
	je check_signal_strength_found
	incq %rcx
	jmp check_signal_strength_loop

check_signal_strength_found:
	movl %edx, %eax
	imull %esi, %eax
check_signal_strength_not_found:
	ret
