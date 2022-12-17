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
	.string "total file size = %d\n"
root_node_name_str:
	.string "/"
file_scan_str:
	.string "%u %s\n"

// struct dir_entry:
// type char            -> 'd'
// name char[99]        -> 0x1(%ptr)
// entry_count int32    -> 0x64(%ptr)
// entries *entry[100]  -> 0x68(%ptr)
// total size = 0x68 + 0x320 = 0x388

// struct file_entry:
// type char            -> 'f'
// name char[99]        -> 0x1(%ptr)
// size int32           -> 0x64(%ptr)
// total size = 0x64 + 0x4 = 0x68

process_part_1:
	push %rbp
	mov %rsp, %rbp
	// (%rsp)(0x8)	      -> input string
	// (0x8)(%rsp)(0x8)  -> root node
	// (0x10)(%rsp)(0x4) -> result
	subq $0x20, %rsp

	movq %rdi, (%rsp)

	leaq root_node_name_str(%rip), %rdi
	call alloc_dir_node
	test %rax, %rax
	je process_part_1_err
	movq %rax, 0x8(%rsp)

	// assume first line is `cd /`
	// know that find_next_line doesn't modify %rdi
	movq (%rsp), %rdi
	xor %rsi, %rsi
	call find_next_line

	leaq (%rdi, %rax, 1), %rdi
	movq 0x8(%rsp), %rsi
	call process_input

	movq 0x8(%rsp), %rdi
	movl $0, 0x10(%rsp)
	leaq 0x10(%rsp), %rsi
	call traverse_tree_lt_100_000

	movl 0x10(%rsp), %eax
process_part_1_ret:
	mov %rbp, %rsp
	pop %rbp
	ret
process_part_1_err:
	movq $-1, %rax
	jmp process_part_1_ret


// process_input(char *remaining_input, void *current_node)
process_input:
	push %rbp
	mov %rsp, %rbp
	//     (%rsp)(0x8)  -> char *remaining_input
	// 0x08(%rsp)(0x8)  -> entry *current_node
	// 0x10(%rsp)(0x4)  -> int32 input_index
	// 0x14(%rsp)(0x4)  -> int32 next_entry_index
	// 0x18(%rsp)(0x8)  -> entry *next_node
	// 0x20(%rsp)(0x68) -> char file_name[104]
	subq $0x90, %rsp

	movq %rdi, (%rsp)
	movq %rsi, 0x8(%rsp)
	movl $0, 0x10(%rsp)
	xor %rax, %rax

process_input_start:
	cmpb $0, (%rdi, %rax, 1)
	je process_input_done
	cmpb $'$', (%rdi, %rax, 1)
	je command

	leaq (%rdi, %rax, 1), %rdi
	movq 0x8(%rsp), %rsi
	call process_listing
	cmpq $-1, %rax
	je process_part_1_err

	jmp next_line

command:
	// if ls - we don't really care about the command, just the output
	cmpw $0x736c, 0x2(%rdi, %rax, 1)
	je process_input_ls

	addq $5, %rax
	movl %eax, 0x10(%rsp)
	leaq (%rdi, %rax, 1), %rdi

	// if .. return
	cmpw $0x2e2e, (%rdi)
	je process_input_done

	xor %rax, %rax
	leaq 0x20(%rsp), %rcx
	movb (%rdi, %rax, 1), %dl
cd_name_loop:
	movb %dl, (%rcx)
	incq %rcx
	incq %rax
	movb (%rdi, %rax, 1), %dl
	cmpb $'\n', %dl
	jne cd_name_loop
	movb $0, (%rcx)
	incl %eax
	addl %eax, 0x10(%rsp)

	// find dir in current node and recurse
	// %rcx -> entry index
	// %rdx -> base of list
	// %r8  -> size of list
	xor %rcx, %rcx
	movl %ecx, 0x14(%rsp)
dir_find_loop:
	movl 0x14(%rsp), %ecx
	movq 0x8(%rsp), %rdx
	movl 0x64(%rdx), %r8d
	addq $0x68, %rdx
	incl %ecx
	cmpl %ecx, %r8d
	jl process_input_err
	movq -0x8(%rdx, %rcx, 8), %r9
	leaq 0x20(%rsp), %rdi
	leaq 0x1(%r9), %rsi
	movq %r9, 0x18(%rsp)
	movl %ecx, 0x14(%rsp)
	call strcmp
	jne dir_find_loop

	movq (%rsp), %rdi
	movl 0x10(%rsp), %eax
	addq %rax, %rdi
	movq 0x18(%rsp), %rsi
	call process_input
	cmp $-1, %rax
	je process_input_ret
	addl 0x10(%rsp), %eax
	movl %eax, 0x10(%rsp)
	movq (%rsp), %rdi

	jmp process_input_start

process_input_ls:
	addq $5, %rax
next_line:
	movq (%rsp), %rdi
	movl 0x10(%rsp), %esi
	call find_next_line
	movl %eax, 0x10(%rsp)

	cmpb $0, (%rdi, %rax, 1)
	jne process_input_start

process_input_done:
	movl 0x10(%rsp), %eax
	addq $3, %rax
process_input_ret:
	mov %rbp, %rsp
	pop %rbp
	ret
process_input_err:
	mov $-1, %rax
	jmp process_input_ret

// process_listing(char *listing_start, entry *current_node)
process_listing:
	push %rbp
	mov %rsp, %rbp
	// (%rsp)(0x8)      -> char *listing_start
	// 0x8(%rsp)(0x8)   -> entry *current_node
	// 0x10(%rsp)(0x68) -> char name[104]
	// 0x68(%rsp)(0x4)  -> size
	// 0x6c(%rsp)(0x4)  -> bytes consumed
	subq $0x70, %rsp

	movq %rdi, (%rsp)
	movq %rsi, 0x8(%rsp)
	movl $0, 0x6c(%rsp)

	cmpb $'d', (%rdi)
	je dir

	// `size filename`
	call atoi
	movq %rax, 0x68(%rsp)

	movq (%rsp), %rdi
	movb $' ', %sil
	call strchr

	incq %rax
	leaq 0x10(%rsp), %rcx
filename_loop:
	movb (%rax), %dl
	movb %dl, (%rcx)
	incq %rcx
	incq %rax
	cmpb $'\n', (%rax)
	jne filename_loop
	movb $0, (%rcx)

	subq %rdi, %rax
	mov %eax, 0x6c(%rsp)

	leaq 0x10(%rsp), %rdi
	movl 0x68(%rsp), %esi
	call alloc_file_node
	test %rax, %rax
	je process_listing_err

	movq 0x8(%rsp), %rdi
	// entry->entry_count (start of list struct)
	addq $0x64, %rdi
	movq %rax, %rsi
	call add_to_list
	cmp $-1, %rax
	je process_listing_err

	jmp process_listing_done
dir:
	// `dir dirname`
	movq (%rsp), %rdi
	movb $' ', %sil
	call strchr

	inc %rax
	leaq 0x10(%rsp), %rcx
dirname_loop:
	movb (%rax), %dl
	movb %dl, (%rcx)
	incq %rcx
	incq %rax
	cmpb $'\n', (%rax)
	jne dirname_loop
	movb $0, (%rcx)

	leaq 0x10(%rsp), %rdi
	call alloc_dir_node
	test %rax, %rax
	je process_listing_err

	movq 0x8(%rsp), %rdi
	// entry->entry_count (start of list struct)
	addq $0x64, %rdi
	movq %rax, %rsi
	call add_to_list
	cmp $-1, %rax
	je process_listing_err

process_listing_done:
	movl 0x6c(%rsp), %eax
process_listing_ret:
	mov %rbp, %rsp
	pop %rbp
	ret
process_listing_err:
	mov $-1, %rax
	jmp process_part_1_ret

// chomp(char *string)
chomp:
	xor %rcx, %rcx
chomp_loop:
	cmpb $'\n', (%rdi, %rcx, 1)
	je chomp_found
	inc %rcx
	jmp chomp_loop
chomp_found:
	movb $0, (%rdi, %rcx, 1)
	ret

// find_next_line(char *string, int offset) -> int
find_next_line:
	cmpb $'\n', (%rdi, %rsi, 1)
	je find_next_line_found
	inc %rsi
	jmp find_next_line
find_next_line_found:
	leaq 0x1(%rsi), %rax
	ret

// alloc_dir_node(char *name) -> dir_entry *
alloc_dir_node:
	push %rbp
	mov %rsp, %rbp
	// (%rsp)(0x8)    -> char *name
	// 0x8(%rsp)(0x8) -> allocated node
	subq $0x10, %rsp

	movq %rdi, (%rsp)

	movq $904, %rdi
	call malloc
	test %rax, %rax
	je alloc_dir_node_ret

	movq %rax, 0x8(%rsp)
	movq %rax, %rdi
	movq $0, %rsi
	movq $904, %rdx
	call memset

	movq 0x8(%rsp), %rdi
	movb $'d', (%rdi)

	incq %rdi
	movq (%rsp), %rsi
	call strcpy

	movq 0x8(%rsp), %rax
alloc_dir_node_ret:
	mov %rbp, %rsp
	pop %rbp
	ret

// alloc_file_node(char *name, int size) -> file_entry *
alloc_file_node:
	push %rbp
	mov %rsp, %rbp
	// (%rsp)(0x8)     -> char *name
	// 0x8(%rsp)(0x4)  -> size
	// 0x10(%rsp)(0x8) -> allocated node
	sub $0x20, %rsp

	movq %rdi, (%rsp)
	movl %esi, 0x8(%rsp)

	movq $104, %rdi
	call malloc
	test %rax, %rax
	je alloc_file_node_ret

	movq %rax, 0x10(%rsp)
	movq %rax, %rdi
	xor %rsi, %rsi
	movq $104, %rdx
	call memset

	movq 0x10(%rsp), %rdi
	movb $'f', (%rdi)

	incq %rdi
	movq (%rsp), %rsi
	call strcpy

	movq 0x10(%rsp), %rax
	movl 0x8(%rsp), %esi
	movl %esi, 100(%rax)
alloc_file_node_ret:
	mov %rbp, %rsp
	pop %rbp
	ret

// add_to_list(void *list, void *entry)
add_to_list:
	push %rbp
	mov %rsp, %rbp

	// load capacity
	movl (%rdi), %r10d
	cmp $0x64, %r10d
	jge add_to_list_err

	movq %rsi, 0x4(%rdi, %r10, 8)
	inc %r10d
	movl %r10d, (%rdi)
	xor %rax, %rax
add_to_list_ret:
	mov %rbp, %rsp
	pop %rbp
	ret
add_to_list_err:
	mov $-1, %rax
	jmp add_to_list_ret

// traverse_tree_lt_100_000(void *node, int32 *result) -> int32
traverse_tree_lt_100_000:
	push %rbp
	movq %rsp, %rbp
	//     (%rsp)(0x8) -> void *entry
	// 0x08(%rsp)(0x8) -> int32 *result
	// 0x10(%rsp)(0x4) -> int32 this_node_size
	// 0x14(%rsp)(0x4) -> int32 entry idnex
	subq $0x20, %rsp

	movq %rdi, (%rsp)
	movq %rsi, 0x8(%rsp)
	movl $0, 0x10(%rsp)

	movl 0x64(%rdi), %eax
	test %eax, %eax
	je traverse_tree_lt_100_000_ret

	xor %rcx, %rcx
traverse_tree_lt_100_000_loop:
	movq 0x68(%rdi, %rcx, 8), %rdi
	cmpb $'f', (%rdi)
	je traverse_tree_lt_100_000_file
	movl %ecx, 0x14(%rsp)
	call traverse_tree_lt_100_000
	addl %eax, 0x10(%rsp)
	movl 0x14(%rsp), %ecx
	jmp traverse_tree_lt_100_000_next

traverse_tree_lt_100_000_file:
	movl 0x64(%rdi), %eax
	addl %eax, 0x10(%rsp)
traverse_tree_lt_100_000_next:
	movq (%rsp), %rdi
	movl 0x64(%rdi), %edx
	incl %ecx
	cmpl %edx, %ecx
	jl traverse_tree_lt_100_000_loop

	movl 0x10(%rsp), %eax
	cmpl $100000, %eax
	jg traverse_tree_lt_100_000_ret
	movq 0x8(%rsp), %rdx
	addl %eax, (%rdx)
traverse_tree_lt_100_000_ret:
	movq %rbp, %rsp
	pop %rbp
	ret
