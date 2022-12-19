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
	.string "visible trees = %d\n"

process_part_1:
	push %rbp
	mov %rsp, %rbp
	//     (%rsp)(0x8) -> input
	// 0x08(%rsp)(0x4) -> width
	// 0x0c(%rsp)(0x4) -> input size
	subq $0x10, %rsp

	movq %rdi, (%rsp)

	movl $'\n', %esi
	call index
	subq (%rsp), %rax
	movl %eax, 0x8(%rsp)

	movq (%rsp), %rdi
	call strlen
	movl %eax, 0xc(%rsp)

	movq (%rsp), %rdi
	movl 0xc(%rsp), %esi
	movl 0x8(%rsp), %edx
	call find_visible_trees

process_part_1_done:
	mov %rbp, %rsp
	pop %rbp
	ret

// find_visible_trees(char *input, int32 input_size, int32 width) -> int32 visible count
find_visible_trees:
	// %rdi -> input
	// %esi -> input size
	// %r8d-> line length
	leal 0x1(%edx), %r8d

	// %r9d -> visible count, initialized with value of start+end rows
	leal -1(%r8d), %r9d
	shl %r9d
	// %ecx -> char index
	movl %r8d, %ecx

find_visible_trees_loop:
	// %eax -> line start index
	// %edx -> line end index
	xor %edx, %edx
	movl %ecx, %eax
	idiv %r8d
	imul %r8d, %eax
	leal -2(%eax, %r8d, 1), %edx

	cmpl %eax, %ecx
	je visible
	cmp %edx, %ecx
	je visible
	// new-line
	jg not_visible

	// %r10d -> comparison char index
	leal -1(%ecx), %r10d
scan_left_loop:
	movb (%rdi, %r10, 1), %r11b
	cmpb %r11b, (%rdi, %rcx, 1)
	jle not_visible_left
	decl %r10d
	cmpl %r10d, %eax
	jg visible
	jmp scan_left_loop
not_visible_left:
	leal 1(%ecx), %r10d
scan_right_loop:
	movb (%rdi, %r10, 1), %r11b
	cmpb %r11b, (%rdi, %rcx, 1)
	jle not_visible_right
	incl %r10d
	cmpl %r10d, %edx
	jl visible
	jmp scan_right_loop
not_visible_right:
	movl %ecx, %r10d
	subl %r8d, %r10d
scan_up_loop:
	movb (%rdi, %r10, 1), %r11b
	cmpb %r11b, (%rdi, %rcx, 1)
	jle not_visible_up
	subl %r8d, %r10d
	cmpl $0, %r10d
	jl visible
	jmp scan_up_loop
not_visible_up:
	movl %ecx, %r10d
	addl %r8d, %r10d
scan_down_loop:
	movb (%rdi, %r10, 1), %r11b
	cmpb %r11b, (%rdi, %rcx, 1)
	jle not_visible
	addl %r8d, %r10d
	cmpl %esi, %r10d
	jg visible
	jmp scan_down_loop
visible:
	incl %r9d
not_visible:
	incl %ecx
	movl %esi, %r11d
	subl %r8d, %r11d
	cmpl %ecx, %r11d
	jg find_visible_trees_loop

	movl %r9d, %eax
	ret
