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
	call process_part_2
	cmp $-1, %rax
	je err

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
	.string "visible trees = %d\n"
result_2_fmt_str:
	.string "best scenic score = %d\n"

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

	mov %rbp, %rsp
	pop %rbp
	ret

process_part_2:
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
	call find_best_scenic_score

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

// find_best_scenic_score(char *input, int32 input_size, int32 width) -> int32 visible count
find_best_scenic_score:
	push %r12

	// %rdi -> input
	// %esi -> input size
	// %r8d-> line length
	leal 0x1(%edx), %r8d

	// %r9d -> best scenic score, 0 at first
	xor %r9d, %r9d
	// %ecx -> char index - first line has no scoring trees
	mov %r8d, %ecx

find_best_scenic_score_loop:
	// %eax -> line start index
	// %edx -> line end index
	xor %edx, %edx
	movl %ecx, %eax
	idiv %r8d
	imul %r8d, %eax
	leal -2(%eax, %r8d, 1), %edx

	// %r12d -> current tree score
	xor %r12d, %r12d

	cmp %edx, %ecx
	// right edge or new-line
	jg next_char

	// %r10d -> comparison char index
	movl %ecx, %r10d
	cmpl %eax, %r10d
	// on left edge, no left score
	jle next_char
	leal -1(%ecx), %r10d
score_left_loop:
	movb (%rdi, %r10, 1), %r11b
	cmpb %r11b, (%rdi, %rcx, 1)
	jle score_left
	decl %r10d
	cmpl %r10d, %eax
	jle score_left_loop
	incl %r10d
score_left:
	movl %ecx, %r11d
	subl %r10d, %r11d
	movl %r11d, %r12d
score_right_init:
	movl %ecx, %r10d
	cmpl %edx, %r10d
	// on right edge, no right score
	je next_char
	leal 1(%ecx), %r10d
score_right_loop:
	movb (%rdi, %r10, 1), %r11b
	cmpb %r11b, (%rdi, %rcx, 1)
	jle score_right
	incl %r10d
	cmpl %r10d, %edx
	jge score_right_loop
	decl %r10d
score_right:
	movl %r10d, %r11d
	subl %ecx, %r11d
	imul %r11d, %r12d
score_up_init:
	movl %ecx, %r10d
	cmpl %r8d, %r10d
	// on top edge, no top score
	jl next_char
	subl %r8d, %r10d
score_up_loop:
	movb (%rdi, %r10, 1), %r11b
	cmpb %r11b, (%rdi, %rcx, 1)
	jle score_up
	subl %r8d, %r10d
	cmpl $0, %r10d
	jge score_up_loop
	addl %r8d, %r10d
score_up:
	// %eax, %edx (beginning/end of line no longer relevant)
	movl %ecx, %eax
	subl %r10d, %eax
	xor %edx, %edx
	div %r8d
	imul %eax, %r12d
score_down_init:
	movl %esi, %r11d
	subl %r8d, %r11d
	cmpl %r11d, %ecx
	// on bottom edge, no top score
	jge next_char
	movl %ecx, %r10d
	addl %r8d, %r10d
score_down_loop:
	movb (%rdi, %r10, 1), %r11b
	cmpb %r11b, (%rdi, %rcx, 1)
	jle score_down
	addl %r8d, %r10d
	cmpl %esi, %r10d
	jle score_down_loop
	subl %r8d, %r10d
score_down:
	movl %r10d, %eax
	subl %ecx, %eax
	xor %edx, %edx
	div %r8d
	imul %eax, %r12d
score_char:
	cmpl %r9d, %r12d
	cmovg %r12d, %r9d
next_char:
	incl %ecx
	movl %esi, %r11d
	subl %r8d, %r11d
	cmpl %ecx, %r11d
	jg find_best_scenic_score_loop

	movl %r9d, %eax
	pop %r12
	ret
