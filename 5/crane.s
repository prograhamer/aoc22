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
	call _process_part_1

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

result_fmt_str:
	.string "value = %d\n"
invalid_args_str:
	.string "invalid arguments, expected input filename"
error_str:
	.string "an error occurred :("
full_str:
	.string "stack full!"
scan_format_str:
	.string "move %u from %u to %u"

_process_part_1:
	push %rbp
	mov %rsp, %rbp
	// (%rsp)(0x8)     -> char  *file_contents
	// 0x8(%rsp)(0x50) -> char  *stacks[]
	subq $0x60, %rsp

	movq %rdi, (%rsp)

	leaq 0x8(%rsp), %rdi
	call allocate_stacks

	movq (%rsp), %rdi
	leaq 0x8(%rsp), %rsi
	call load_stacks

	movq %rax, %rdi
	leaq 0x8(%rsp), %rsi
	call execute_instructions

	leaq 0x8(%rsp), %rdi
	call print_stacks

	mov %rbp, %rsp
	pop %rbp
	ret

// allocate_stacks(char *stacks[])
allocate_stacks:
	push %rbp
	mov %rsp, %rbp
	// (%rsp)(0x8)    -> char *stacks[]
	// 0x8(%rsp)(0x4) -> stack index
	subq $0x10, %rsp

	movq %rdi, (%rsp)

	// allocate stacks as char[512] on the heap
	xor %rcx, %rcx
allocate_stacks_loop:
	movl %ecx, 0x8(%rsp)
	movq $0x200, %rdi
	call malloc
	cmp $0, %rax
	je allocate_stacks_err

	movq (%rsp), %rdx
	movl 0x8(%rsp), %ecx
	movq %rax, (%rdx, %rcx, 8)
	movq %rax, %rdi
	movq $0, %rsi
	movq $0x200, %rdx
	call memset
	movl 0x8(%rsp), %ecx
	inc %rcx
	cmp $10, %rcx
	jl allocate_stacks_loop

allocate_stacks_done:
	mov %rbp, %rsp
	pop %rbp
	ret
allocate_stacks_err:
	mov $-1, %rax
	jmp allocate_stacks_done

load_stacks:
	push %rbp
	mov %rsp, %rbp
	// (%rsp)(0x8)     -> char  *file_contents
	// 0x8(%rsp)(0x4)  -> int32 newline_index
	// 0xc(%rsp)(0x4)  -> int32 stack index
	// 0x10(%rsp)(0x8) -> char  **stacks[]
	subq $0x20, %rsp

	movq %rdi, (%rsp)
	movq %rsi, 0x10(%rsp)

find_new_line:
	xor %rcx, %rcx
	movq (%rsp), %rdi
evaluate_lf_loop:
	cmpb $'\n', (%rdi, %rcx, 1)
	je found_new_line
	inc %rcx
	jmp evaluate_lf_loop

found_new_line:
	// empty line denotes start of instructions
	cmp $0, %rcx
	je load_stacks_reverse

_process_preamble_line:
	// %rbx = stack index
	mov $0, %rbx

init_stack_loop:
	// %rax = index of stack char in line
	// %r8b = character at index
	mov %rbx, %rax
	shl $2, %rax
	add $1, %rax
	movb (%rdi, %rax, 1), %sil

	cmpb $'A', %sil
	jl next_stack

	movq %rdi, (%rsp)
	movl %ecx, 0x8(%rsp)
	// get pointer to stack[]
	movq 0x10(%rsp), %rdi
	// get pointer to stack
	movq (%rdi, %rbx, 8), %rdi
	call add_to_stack
	cmp $0, %rax
	jl full
	movq (%rsp), %rdi
	movl 0x8(%rsp), %ecx

next_stack:
	inc %rbx
	mov %rbx, %rax
	shl $2, %rax
	add $1, %rax
	cmp %rax, %rcx
	jg init_stack_loop

	inc %rcx
	addq %rcx, %rdi
	movq %rdi, (%rsp)
	jmp find_new_line

full:
	mov full_str(%rip), %rdi
	call puts
load_stacks_reverse:
	// save the modified text pointer to the start of the instructions
	inc %rdi
	movq %rdi, (%rsp)

	xor %rcx, %rcx
load_stacks_reverse_loop:
	movq 0x10(%rsp), %rdi
	movq (%rdi, %rcx, 8), %rdi
	movl %ecx, 0xc(%rsp)
	call reverse_stack
	movl 0xc(%rsp), %ecx
	inc %ecx
	cmp $10, %ecx
	jl load_stacks_reverse_loop

load_stacks_done:
	movq (%rsp), %rax
	mov %rbp, %rsp
	pop %rbp
	ret

// execute_instructions(char *text, void **stacks[])
execute_instructions:
	push %rbp
	mov %rsp, %rbp
	// (%rsp)(0x8)     -> text
	// 0x8(%rsp)(0x8)  -> pointer to *stacks[]
	// 0x10(%rsp)(0x4) -> count
	// 0x14(%rsp)(0x4) -> from
	// 0x18(%rsp)(0x4) -> to
	// 0x1c(%rsp)(0x4) -> newline index
	subq $0x20, %rsp

	movq %rdi, (%rsp)
	movq %rsi, 0x8(%rsp)

execute_find_new_line:
	xor %rcx, %rcx
	movq (%rsp), %rdi
execute_new_line_loop:
	cmpb $0, (%rdi, %rcx, 1)
	je execute_done
	cmpb $'\n', (%rdi, %rcx, 1)
	je execute_found_new_line
	inc %rcx
	jmp execute_new_line_loop

execute_found_new_line:
	movl %ecx, 0x1c(%rsp)
	movb $0, (%rdi, %rcx, 1)
	leaq scan_format_str(%rip), %rsi
	leaq 0x10(%rsp), %rdx
	leaq 0x14(%rsp), %rcx
	leaq 0x18(%rsp), %r8
	xor %rax, %rax
	call sscanf

	// %rdx = number of times to perform operation
	// %r8d = source stack (zero-indexed)
	// %r9d = destination stack (zero-indexed)
	movl 0x10(%rsp), %edx
	movl 0x14(%rsp), %r8d
	dec %r8d
	movl 0x18(%rsp), %r9d
	dec %r9d

	// update text pointer for next new line
	movq (%rsp), %rdi
	movl 0x1c(%rsp), %ecx
	leaq 0x1(%rdi, %rcx, 1), %rdi
	movq %rdi, (%rsp)

	xor %rcx, %rcx
execute_loop:
	cmp %ecx, %edx
	jle execute_find_new_line
	movq 0x8(%rsp), %rdi
	movq (%rdi, %r8, 8), %rdi
	call remove_from_stack
	movq 0x8(%rsp), %rdi
	movq (%rdi, %r9, 8), %rdi
	mov %al, %sil
	call add_to_stack
	inc %rcx
	jmp execute_loop

execute_done:
	mov %rbp, %rsp
	pop %rbp
	ret

// add_to_stack(void *stack, char value) -> int
add_to_stack:
	push %rbp
	mov %rsp, %rbp

	// load capacity
	movl (%rdi), %r10d
	cmp $0x1fc, %r10d
	jge err

	movb %sil, 0x4(%rdi, %r10, 1)
	inc %r10d
	movl %r10d, (%rdi)
	xor %rax, %rax
add_to_stack_ret:
	mov %rbp, %rsp
	pop %rbp
	ret
add_to_stack_err:
	mov $-1, %rax
	jmp add_to_stack_ret

// remove_from_stack(void *stack) -> char
remove_from_stack:
	movl (%rdi), %r10d
	test %r10d, %r10d
	je remove_from_stack_err

	dec %r10d
	xor %rax, %rax
	movb 0x4(%rdi, %r10, 1), %al
	movl %r10d, (%rdi)

remove_from_stack_done:
	ret
remove_from_stack_err:
	mov $-1, %rax
	jmp remove_from_stack_done

// reverse_stack(void *stack)
reverse_stack:
	push %rbp
	mov %rsp, %rbp

	movl (%rdi), %ecx
	// if stack empty or has one element, nothing to do!
	cmp $2, %ecx
	jl reverse_stack_done
	dec %ecx

	// %rax = start pointer
	leaq 0x4(%rdi), %rax
	// %rdx = end pointerr
	leaq 0x4(%rdi, %rcx, 1), %rdx

reverse_stack_loop:
	movb (%rax), %r8b
	movb (%rdx), %r9b
	movb %r8b, (%rdx)
	movb %r9b, (%rax)
	inc %rax
	dec %rdx

	cmp %rax, %rdx
	jg reverse_stack_loop

reverse_stack_done:
	mov %rbp, %rsp
	pop %rbp
	ret

// print_stacks(voic **stacks[])
print_stacks:
	push %rbp
	mov %rsp, %rbp
	// (%rsp)(0x8)     -> **stacks[]
	// 0x8(%rsp)(0x10) -> result string
	subq $0x20, %rsp

	movq %rdi, (%rsp)

	// stack index
	xor %rcx, %rcx
	// string index
	xor %r8, %r8
print_stacks_loop:
	movq (%rsp), %rdx
	movq (%rdx, %rcx, 8), %rdx

	movl (%rdx), %eax
	cmp $0, %eax
	je print_stacks_next

	movb 0x3(%rdx, %rax, 1), %r9b
	movb %r9b, 0x8(%rsp, %r8, 1)
	inc %r8
print_stacks_next:
	inc %rcx
	cmp $10, %rcx
	jge print_stacks_done
	jmp print_stacks_loop

print_stacks_done:
	movb $0, 0x8(%rsp, %r8, 1)
	leaq 0x8(%rsp), %rdi
	call puts

	mov %rbp, %rsp
	pop %rbp
	ret
