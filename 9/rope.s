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

	movl $400, %esi
	movl $2, %edx
	call calc_tail_locations

process_part_1_ret:
	mov %rbp, %rsp
	pop %rbp
	ret


process_part_2:
	push %rbp
	mov %rsp, %rbp

	movl $400, %esi
	movl $10, %edx
	call calc_tail_locations

	movq %rbp, %rsp
	pop %rbp
	ret

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
	movq $'.', %rsi
	movq (%rsp), %rdx
	call memset
allocate_map_ret:
	mov %rbp, %rsp
	pop %rbp
	ret

// calc_tail_locations(char *input, int width, int rope_length) -> int count
calc_tail_locations:
	push %rbp
	push %rbx
	push %r12
	push %r13
	push %r14
	push %r15
	mov %rsp, %rbp
	// -0x08(%rbp)(0x8) -> map
	// -0x0c(%rbp)(0x4) -> height/width
	// -0x10(%rbp)(0x4) -> rope_length
	// (%rsp) -> segment positions
	subq $0x10, %rsp

	// %rbx -> input
	// %r12d, %r13d -> leading segment location x, y
	// %r14d, %r15d -> following segment location x, y
	movq %rdi, %rbx
	movl %esi, -0xc(%rbp)
	movl %edx, -0x10(%rbp)

	// allocate space for all rope segment positions, int32 for x and y each
	movl %edx, %r12d
	shl $3, %r12
	subq %r12, %rsp
	// ensure stack alignment
	andq $-16, %rsp

	// everything starts at the midpoint
	movl %esi, %r14d
	sar %r14d
	xor %rcx, %rcx

calc_tail_locations_init_loop:
	movl %r14d, (%rsp, %rcx, 8)
	movl %r14d, 0x4(%rsp, %rcx, 8)
	incq %rcx
	cmpq %rcx, %rdx
	jg calc_tail_locations_init_loop

	movq %rsi, %rdi
	call allocate_map
	test %rax, %rax
	je calc_tail_locations_err
	movq %rax, -0x8(%rbp)

calc_tail_locations_line_loop:
	leaq 2(%rbx), %rdi
	call atoi
	test %rax, %rax
	je calc_tail_locations_err_free

calc_tail_locations_movement_loop:
	// load current direction character
	movb (%rbx), %sil
	// load head coordinates
	movl (%rsp), %r12d
	movl 0x4(%rsp), %r13d

	cmpb $'R', %sil
	jne calc_tail_locations_cmp_left
	incl %r12d
	jmp calc_tail_locations_move_body
calc_tail_locations_cmp_left:
	cmpb $'L', %sil
	jne calc_tail_locations_cmp_up
	decl %r12d
	jmp calc_tail_locations_move_body
calc_tail_locations_cmp_up:
	cmpb $'U', %sil
	jne calc_tail_locations_cmp_down
	incl %r13d
	jmp calc_tail_locations_move_body
calc_tail_locations_cmp_down:
	cmpb $'D', %sil
	jne calc_tail_locations_err_free
	decl %r13d

calc_tail_locations_move_body:
	movl %r12d, (%rsp)
	movl %r13d, 0x4(%rsp)

	// first body segment is 1
	movl $1, %ecx

calc_tail_locations_move_body_loop:
	movl (%rsp, %rcx, 8), %r14d
	movl 0x4(%rsp, %rcx, 8), %r15d

move_segment:
	movl %r12d, %r8d
	movl %r13d, %r9d
	subl %r14d, %r8d
	subl %r15d, %r9d

	movl $1, %edx
	movl $-1, %esi

	cmpl $-1, %r8d
	jl move_segment_left
	cmpl $1, %r8d
	jg move_segment_right

	cmpl $-1, %r9d
	jl move_segment_down
	cmpl $1, %r9d
	jg move_segment_up

	jmp move_segment_done

move_segment_left:
	// moving left, if we're off up/down we need to move diagonally
	xor %r10d, %r10d
	cmpl $0, %r9d
	cmovl %esi, %r10d
	cmovg %edx, %r10d
	decl %r14d
	addl %r10d, %r15d
	jmp move_segment_done
move_segment_right:
	// move right, if we're off up/down we need to move diagonally
	xor %r10d, %r10d
	cmpl $0, %r9d
	cmovl %esi, %r10d
	cmovg %edx, %r10d
	incq %r14
	addq %r10, %r15
	jmp move_segment_done
move_segment_down:
	// move down, if we're off left/right we need to move diagonally
	xor %r10, %r10
	cmpl $0, %r8d
	cmovl %esi, %r10d
	cmovg %edx, %r10d
	decl %r15d
	addl %r10d, %r14d
	jmp move_segment_done
move_segment_up:
	// move up, if we're off left/right we need to move diagonally
	xor %r10d, %r10d
	cmpl $0, %r8d
	cmovl %esi, %r10d
	cmovg %edx, %r10d
	incl %r15d
	addl %r10d, %r14d

move_segment_done:
	// following segment is now leading, save following segment position
	movl %r14d, %r12d
	movl %r15d, %r13d
	movl %r14d, (%rsp, %rcx, 8)
	movl %r15d, 0x4(%rsp, %rcx, 8)

	incq %rcx
	cmpl %ecx, -0x10(%rbp)
	jg calc_tail_locations_move_body_loop

	// mark tail location visited
	movq -0x8(%rbp), %r10
	imull -0xc(%rbp), %r15d
	addl %r14d, %r15d
	movb $'T', (%r10, %r15, 1)

	decq %rax
	jne calc_tail_locations_movement_loop

calc_tail_locations_next_line:
	incq %rbx
	cmpb $'\n', -1(%rbx)
	jne calc_tail_locations_next_line
	cmpb $0, (%rbx)
	jne calc_tail_locations_line_loop

	movq -0x8(%rbp), %rdi
	movl -0xc(%rbp), %esi
	call count_tail_locations
	movl %eax, -0xc(%rbp)

	movq -0x8(%rbp), %rdi
	call free

	movl -0xc(%rbp), %eax

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
	movq -0x8(%rbp), %rdi
	call free
calc_tail_locations_err:
	movq $-1, %rax
	jmp calc_tail_locations_ret

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

	ret

// print_map(void *map, int width) -> void
print_map:
	push %rbp
	mov %rsp, %rbp
	//    (%rsp)(0x8) -> map
	// 0x08(%rsp)(0x4) -> width
	// 0x0c(%rsp)(0x4) -> current line
	// 0x10(%rsp)(0x4) -> newline string
	subq $20, %rsp

	movq %rdi, (%rsp)
	movl %esi, 0x8(%rsp)

	movl $0x0a, 0x10(%rsp)
	xor %rcx, %rcx

print_map_loop:
	movl %ecx, 0xc(%rsp)
	movq $1, %rdi
	movq (%rsp), %rsi
	movl 0x8(%rsp), %edx
	call write

	movq $1, %rdi
	leaq 0x10(%rsp), %rsi
	movq $2, %rdx
	call write

	movl 0xc(%rsp), %ecx
	movl 0x8(%rsp), %eax
	addq %rax, (%rsp)
	incl %ecx
	cmpl %ecx, %eax
	jg print_map_loop

	mov %rbp, %rsp
	pop %rbp
	ret
