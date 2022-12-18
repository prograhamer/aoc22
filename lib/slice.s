// struct slice {
// int32 cap      ->    (%ptr)
// int32 size     -> 0x4(%ptr)
// void **entries -> 0x8(%ptr)
// }

// slice_init(int32 cap) -> void *slice
slice_init:
	push %rbp
	mov %rsp, %rbp
	// (%rsp)(0x8)    -> allocated chunk
	// 0x8(%rsp)(0x4) -> cap
	subq $0x10, %rsp

	movl %edi, 0x8(%rsp)

	// Allocate enough space for cap pointers + 4 bytes cap, 4 bytes size
	movq $0x10, %rdi
	call malloc
	test %rax, %rax
	je slice_init_ret
	movq %rax, (%rsp)

	// Zero base struct memory
	movq %rax, %rdi
	xor %rsi, %rsi
	movl $0x10, %edx
	call memset

	// Set cap on struct
	movl 0x8(%rsp), %edi
	movl %edi, (%rax)

	// Allocate entries array - cap * 8 to hold cap * pointer
	shl $3, %rdi
	call malloc
	test %rax, %rax
	je slice_init_ret_free_base

	// Save entries pointer to struct
	movq (%rsp), %rdi
	movq %rax, 0x8(%rdi)

	// Zero entries memory
	movq %rax, %rdi
	xor %rsi, %rsi
	movl 0x8(%rsp), %edx
	shl $3, %rdx
	call memset

	movq (%rsp), %rax
slice_init_ret:
	mov %rbp, %rsp
	pop %rbp
	ret
slice_init_ret_free_base:
	movq (%rsp), %rdi
	call free
	xor %rax, %rax
	jmp slice_init_ret

// slice_add(void *slice, void *entry) -> int
slice_add:
	movl (%rdi), %eax
	movl 0x4(%rdi), %ecx

	cmpl %eax, %ecx
	je slice_add_alloc

slice_add_entry:
	movq 0x8(%rdi), %rdx
	movq %rsi, (%rdx, %rcx, 8)
	incl %ecx
	movl %ecx, 0x4(%rdi)

	xor %rax, %rax
	ret
slice_add_alloc:
	push %rbp
	mov %rsp, %rbp
	//     (%rsp)(0x8) -> slice
	// 0x08(%rsp)(0x8) -> entry
	// 0x10(%rsp)(0x8) -> added capacity
	subq $0x20, %rsp

	movq %rdi, (%rsp)
	movq %rsi, 0x8(%rsp)

	movq 0x8(%rdi), %rdi
	// allocate more capacity
	movq %rax, %rsi
	shl $1, %rsi
	// save added capacity
	movl %esi, %edx
	subl %eax, %edx
	movl %edx, 0x10(%rsp)
	// convert cap to bytes
	shl $3, %rsi
	call realloc
	test %rax, %rax
	je slice_add_alloc_err

	// save new entries pointer and capacity
	mov (%rsp), %rdi
	movq %rax, 0x8(%rdi)
	movl 0x10(%rsp), %edx
	addl %edx, (%rdi)

	// Zero newly allocated memory
	movq %rax, %rdi
	movl 0x10(%rsp), %edx
	shl $3, %rdx
	addq %rdx, %rdi
	xor %rsi, %rsi
	call memset

	// Store values in registers to continue with slice_add_entry
	movq (%rsp), %rdi
	movq 0x8(%rsp), %rsi
	movl 0x4(%rdi), %ecx

	mov %rbp, %rsp
	pop %rbp
	jmp slice_add_entry
slice_add_alloc_err:
	movq $-1, %rax
	mov %rbp, %rsp
	pop %rbp
	ret

// slice_get(void *slice, int32 index) -> void *entry
slice_get:
	movl 0x4(%rdi), %eax
	cmpl %esi, %eax
	jle slice_get_null
	movq 0x8(%rdi), %rdx
	movq (%rdx, %rsi, 8), %rax
	ret
slice_get_null:
	xor %rax, %rax
	ret
