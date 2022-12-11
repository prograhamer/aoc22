.data
filename:
	.string "calories.test"
bufsize:
	.long 10465
buf:
	.zero 10465
bestelfstr:
	.string "the best elf is #"
bestelfstr_end:
	.equ bestelfstr_len, bestelfstr_end - bestelfstr
withstr:
	.string " with "
withstr_end:
	.equ withstr_len, withstr_end - withstr
calstr:
	.string " calories\n"
calstr_end:
	.equ calstr_len, calstr_end - calstr

.text
.globl _start
_start:
	sub $12, %rsp
	// %rsp+8 = read
	// $rsp+0 = fd
	// $rsp-4*elf-4 = calorie count

	// Open file
	movq $2, %rax
	movq $filename, %rdi
	xor %rsi, %rsi
	xor %rdx, %rdx
	syscall
	movq %rax, (%rsp)

	// Read file
	movq $0, %rax
	movq (%rsp), %rdi
	movq $buf, %rsi
	movq $bufsize, %rdx
	movl (%rdx), %edx
	syscall
	movl %eax, 8(%rsp)

	// Close file
	movq $3, %rax
	movq (%rsp), %rdi
	syscall

parse:
	// Initialize base reg=buf, count=0
	movq $buf, %rbx
	xor %rcx, %rcx

	// %r8 is elf counter!
	xor %r8, %r8
	addq $1, %r8
	// %r9 is elf pointer!
	leaq -4(%rsp), %r9
	xor %rax, %rax
	movl %eax, (%r9)
loop:
	leaq (%rbx, %rcx, 1), %rdx
	movb (%rdx), %dl
	cmpb $0x30, %dl
	jl notnumber
	cmpb $0x39, %dl
	jg notnumber
	imul $10, %eax
	subb $0x30, %dl
	and $0xff, %edx
	addl %edx, %eax

	// while ecx <= read length
	incl %ecx
	cmpl 8(%rsp), %ecx
	jle loop


	// r14 = # of best counts output
	xor %r14, %r14

findbest:
	// find the greediest boi
	// ax = best index, dx = best calories
	xor %rax, %rax
	xor %rcx, %rcx
	xor %rdx, %rdx
	leaq -4(%rsp), %rbx

loop2:
	cmpl (%rbx), %edx
	jg notasgreedy
	movl (%rbx), %edx
	mov %rcx, %rax
notasgreedy:
	subq $4, %rbx
	inc %rcx
	cmp %rcx, %r8
	jg loop2

best:
	incl %eax
	mov %eax, (%rsp)
	mov %edx, 4(%rsp)

	// Print prefix
	movq $1, %rax
	movq $1, %rdi
	movq $bestelfstr, %rsi
	movq $bestelfstr_len, %rdx
	syscall

	// Write elf #
	xor %rax, %rax
	mov (%rsp), %eax
	mov $buf, %rbx
numloop:
	xor %rdx, %rdx
	mov $10, %ecx
	div %ecx
	addb $0x30, %dl
	movb %dl, (%rbx)
	inc %rbx
	test %eax, %eax
	jne numloop

	movq $1, %rax
	movq $1, %rdi
	movq $buf, %rsi
	subq $buf, %rbx
	movq %rbx, %rdx
	syscall

	// Print with
	movq $1, %rax
	movq $1, %rdi
	movq $withstr, %rsi
	movq $withstr_len, %rdx
	syscall

	// Write calorie number
	xor %rax, %rax
	mov 4(%rsp), %eax
	mov $buf, %rbx
numloop2:
	xor %rdx, %rdx
	mov $10, %ecx
	div %ecx
	addb $0x30, %dl
	movb %dl, (%rbx)
	inc %rbx
	test %eax, %eax
	jne numloop2

	movq $buf, %r10
	movq %rbx, %r11
	decq %r11
revloop:
	cmp %r10, %r11
	jle done
	movb (%r10), %r12b
	movb (%r11), %r13b
	movb %r12b, (%r11)
	movb %r13b, (%r10)
	incq %r10
	decq %r11
	jmp revloop

done:
	movq $1, %rax
	movq $1, %rdi
	movq $buf, %rsi
	subq $buf, %rbx
	movq %rbx, %rdx
	syscall

	// Print calories
	movq $1, %rax
	movq $1, %rdi
	movq $calstr, %rsi
	movq $calstr_len, %rdx
	syscall

	xor %rax, %rax
	movl (%rsp), %eax
	shl $2, %eax
	mov %rsp, %rbx
	sub %rax, %rbx
	movl $0, (%rbx)

	incq %r14
	cmp $3, %r14
	jne findbest

	jmp exit

notnumber:
	cmpb $0xa, %dl
	jne error

	// new number -> add existing eax and reset accumulator
	addl %eax, (%r9)
	xor %rax, %rax
	incl %ecx
	cmpl 8(%rsp), %ecx
	je findbest
	leaq (%rbx, %rcx, 1), %rdx
	cmpb $0xa, (%rdx)
	jne loop

newelf:
	incl %ecx
	subq $4, %r9
	addq $1, %r8
	movl %eax, (%r9)
	jmp loop

exit:
	// Exit(0)
	movq $60, %rax
	movq $0, %rbx
	syscall
error:
	movq $60, %rax
	movq $1, %rbx
	syscall
