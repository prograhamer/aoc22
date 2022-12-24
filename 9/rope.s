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
	.string "locations visited by tail = %d\n"

process_part_1:
	push %rbp
	mov %rsp, %rbp
	//     (%rsp)(0x8) -> input
	// 0x08(%rsp)(0x8) -> map
	subq $0x10, %rsp

	movq %rdi, (%rsp)

	movl $400, %esi
	call calc_tail_locations

process_part_1_ret:
	mov %rbp, %rsp
	pop %rbp
	ret
process_part_1_err:
	movq $-1, %rax
	jmp process_part_1_ret

// allocate_map(int width)
allocate_map:
	push %rbp
	mov %rsp, %rbp
	// (%rsp)(0x8) -> size
	subq $0x10, %rsp

	imul %rdi, %rdi
	movq %rdi, (%rsp)
	call malloc
	test %rax, %rax
	je allocate_map

	movq %rax, %rdi
	xor %rsi, %rsi
	movq (%rsp), %rdx
	call memset
allocate_map_ret:
	mov %rbp, %rsp
	pop %rbp
	ret

// calc_tail_locations(char *input, int width) -> int count
calc_tail_locations:
	push %rbp
	push %rbx
	push %r12
	push %r13
	push %r14
	push %r15
	mov %rsp, %rbp
	//    (%rsp)(0x8) -> map
	// 0x8(%rsp)(0x4) -> height/width
	subq $0x18, %rsp

	// %rbx (caller owned) -> current instruction
	// %r12, %r13 (caller owned) -> head x/y coordinates
	// %r14, %r15 (caller owned) -> tail x/y coordinates
	movq %rdi, %rbx
	movl %esi, 0x8(%rsp)

	// everything starts at the midpoint
	movq %rsi, %r12
	sar %r12
	movq %r12, %r13
	movq %r12, %r14
	movq %r12, %r15

	movq %rsi, %rdi
	call allocate_map
	test %rax, %rax
	je calc_tail_locations_err
	movq %rax, (%rsp)

line_loop:
	leaq 2(%rbx), %rdi
	call atoi
	test %rax, %rax
	je calc_tail_locations_err_free
	movb (%rbx), %sil

movement_loop:
	cmpb $'R', %sil
	jne cmp_left
	incq %r12
	jmp move_tail
cmp_left:
	cmpb $'L', %sil
	jne cmp_up
	decq %r12
	jmp move_tail
cmp_up:
	cmpb $'U', %sil
	jne cmp_down
	incq %r13
	jmp move_tail
cmp_down:
	cmpb $'D', %sil
	jne calc_tail_locations_err_free
	decq %r13

move_tail:
	movq %r12, %r8
	movq %r13, %r9
	subq %r14, %r8
	subq %r15, %r9

	movq $1, %rdx
	movq $-1, %rcx

	cmpq $-1, %r8
	jl move_tail_left
	cmpq $1, %r8
	jg move_tail_right

	cmpq $-1, %r9
	jl move_tail_down
	cmpq $1, %r9
	jg move_tail_up

	jmp move_tail_done

move_tail_left:
	// moving left, if we're off up/down we need to move diagonally
	xor %r10, %r10
	cmpq $0, %r9
	cmovl %rcx, %r10
	cmovg %rdx, %r10
	decq %r14
	addq %r10, %r15
	jmp move_tail_done
move_tail_right:
	// move right, if we're off up/down we need to move diagonally
	xor %r10, %r10
	cmpq $0, %r9
	cmovl %rcx, %r10
	cmovg %rdx, %r10
	incq %r14
	addq %r10, %r15
	jmp move_tail_done
move_tail_down:
	// move down, if we're off left/right we need to move diagonally
	xor %r10, %r10
	cmpq $0, %r8
	cmovl %rcx, %r10
	cmovg %rdx, %r10
	decq %r15
	addq %r10, %r14
	jmp move_tail_done
move_tail_up:
	// move up, if we're off left/right we need to move diagonally
	xor %r10, %r10
	cmpq $0, %r8
	cmovl %rcx, %r10
	cmovg %rdx, %r10
	incq %r15
	addq %r10, %r14

move_tail_done:
	// mark tail location visited
	movq (%rsp), %r10
	movq %r15, %r11
	imull 0x8(%rsp), %r11d
	addq %r14, %r11
	movb $'T', (%r10, %r11, 1)

	decq %rax
	jne movement_loop

next_line:
	incq %rbx
	cmpb $'\n', -1(%rbx)
	jne next_line
	cmpb $0, (%rbx)
	jne line_loop

	movq (%rsp), %rdi
	movl 0x8(%rsp), %esi
	call count_tail_locations

calc_tail_locations_ret:
	mov %rbp, %rsp
	pop %r15
	pop %r14
	pop %r13
	pop %r12
	pop %rbx
	pop %rbp
	ret
calc_tail_locations_err_free:
	movq 0x8(%rsp), %rdi
	call free
calc_tail_locations_err:
	mov $-1, %rax
	jmp calc_tail_locations_ret

	mov $-1, %rax
	ret

// count_tail_locations(void *map, int width) -> int count
count_tail_locations:
	xor %rax, %rax
	xor %rcx, %rcx
	xor %rdx, %rdx
	imul %rsi, %rsi

count_tail_locations_loop:
	cmpb $'T', (%rdi, %rcx, 1)
	sete %dl
	addq %rdx, %rax
	incq %rcx
	cmpq %rcx, %rsi
	jg count_tail_locations_loop

count_tail_locations_ret:
	ret
