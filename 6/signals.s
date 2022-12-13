.include "../lib/readfile.s"

.text
.globl main
main:
	push %rbp
	mov %rsp, %rbp
	// %rsp -> file contents buffer
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

	leaq result_1_fmt_str(%rip), %rdi
	movq %rax, %rsi
	xor %rax, %rax
	call printf

	movq (%rsp), %rdi
	call process_part_2

	leaq result_2_fmt_str(%rip), %rdi
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
	.string "packet start marker @ %d\n"
result_2_fmt_str:
	.string "message start marker @ %d\n"

process_part_1:
	// %rcx -> string index
	xor %rcx, %rcx

loop:
	// load 2 bytes into %ax -> %al = byte 0, %ah = byte 1
	mov (%rdi, %rcx, 1), %ax
	cmp %al, %ah
	je next1

	// load next 2 bytes %dx -> %dl = byte 2, %dh = byte 3
	mov 0x2(%rdi, %rcx, 1), %dx
	cmp %ah, %dl
	je next2

	cmp %al, %dl
	je next1
	cmp %al, %dh
	je next1

	cmp %ah, %dh
	je next2

	cmp %dl, %dh
	je next3

	leaq 0x4(%rcx), %rax

	ret
next1:
	inc %rcx
	jmp loop
next2:
	add $2, %rcx
	jmp loop
next3:
	add $3, %rcx
	jmp loop

process_part_2:
	// %rcx -> string index of start of sequence
	xor %rcx, %rcx
	xor %rsi, %rsi

outer_loop:
	// %rax -> index of character being tested against all others
	leaq 13(%rcx), %rax
inner_loop_rax:
	// %sil -> character being tested
	movb (%rdi, %rax, 1), %sil
	// %rdx -> index of other character to be tested against one in %sil, initially char immediately before it
	leaq -1(%rax), %rdx
inner_loop_rdx:
	cmpb (%rdi, %rdx, 1), %sil
	je equal

	dec %rdx
	cmp %rcx, %rdx
	jge inner_loop_rdx

	dec %rax
	cmp %rcx, %rax
	jge inner_loop_rax

	add $15, %rax
	ret
equal:
	leaq 0x1(%rdx), %rcx
	jmp outer_loop
