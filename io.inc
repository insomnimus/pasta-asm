initial_stdin_buf_len = 1024
ERROR_BROKEN_PIPE = 0x0000006D

;; fn _read_stdin_bytes(out_str: *str) -> length
proc _read_stdin_bytes uses rbx rsi rdi r12 r15, out_str:PTR ;{
	local buf:PTR
	local capacity:DWORD
	local length:DWORD
	local n_read:DWORD ; temporary, resets each iteration

	mov qword [out_str], rcx
	mov dword [capacity], initial_stdin_buf_len
	mov dword [length], 0
	lea rbx, [n_read] ; we'll store the address of n_read in rbx

	; allocate heap
	try invoke HeapAlloc, <invoke GetProcessHeap>, HEAP_ZERO_MEMORY, initial_stdin_buf_len
	mov qword [buf], rax
	mov rdi, rax ; write index
	try invoke GetStdHandle, STD_INPUT_HANDLE
	mov rsi, rax ; stdin handle

	.loop:
		mov r12d, dword [capacity]
		sub r12d, dword [length]
		jif r12d, be, 1, .realloc ; reallocate if remaining capacity <= 1
		dec r12d ; do not let it write to the last null byte

		invoke ReadFile,\
			rsi,\ ; stdin handle
			rdi,\ ; write pointer
			r12d,\ ; number of bytes to read
			rbx,\ ; out number of bytes read
			nil ; lpOverlapped

		; check return code
		jif eax, e, FALSE, .handle_err

		; increment length and continue the loop
		mov eax, dword [n_read]
		add dword [length], eax

		add rdi, rax ; write-pointer
		jmp .loop

	.handle_err:
		invoke GetLastError
		jif eax, e, ERROR_BROKEN_PIPE, .return
		; some other error - exit the process
		jmp err_exit
		ret

	.realloc:
		sal dword [capacity], 1 ; double cap
		try invoke HeapReAlloc, <invoke GetProcessHeap>, HEAP_ZERO_MEMORY, qword [buf], dword [capacity]

		mov qword [buf], rax ; write the new buffer pointer
		xor r15, r15
		mov r15d, dword [length]
		add rax, r15
		mov rdi, rax
		jmp .loop ; continue loop


	.return:
		mov rax, qword [out_str]
		mov rbx, qword [buf]
		mov qword [rax], rbx
		mov eax, dword [length]

		ret
endp
;}

proc _encode_to_utf16 uses rbx rsi rdi r12 r13, input:PTR, input_len:QWORD, output:PTR ;{
	; mov qword [input], rcx
	mov rsi, rcx
	; mov qword [input_len], rdx
	mov r12, rdx
	;mov qword [output], r8
	mov rdi, r8

	; first get the consoles code page
	try invoke GetConsoleCP
	mov ebx, eax

	try invoke MultiByteToWideChar,\
		ebx,\ ; code page
		0,\ ; flags
		rsi,\ ; string to convert
		r12,\ ; length of the input
		nil,\ ; output
		0 ; output buffer length (0 because we want how much we need to allocate)

		mov r13, rax
		sal r13, 1 ; double for wide char
		try invoke HeapAlloc, <invoke GetProcessHeap>, HEAP_ZERO_MEMORY, r13
		mov qword [rdi], rax ; save allocation

			invoke MultiByteToWideChar,\
		ebx,\ ; code page
		0,\ ; flags
		rsi,\ ; string to convert
		r12,\ ; length of the input
		qword [rdi],\ ; output
		r13 ; output buffer length

	ret
endp
;}

proc read_stdin uses rbx rdi, out_str:PTR ;{
	local bytes:PTR

	mov rdi, rcx

	lea rbx, qword [bytes]
	fastcall _read_stdin_bytes, rbx
	inc rax ; null terminated
	fastcall _encode_to_utf16, qword [rbx], rax, rdi
	mov rbx, rax
	; don't forget to free memory
	try invoke HeapFree, <invoke GetProcessHeap>, 0, qword [bytes]
	mov rax, rbx

	ret
endp
;}

proc is_stdin_tty ;{
	invoke GetStdHandle, STD_INPUT_HANDLE
	invoke GetFileType, eax
	cmp eax, FILE_TYPE_CHAR
	je .true
	mov rax, FALSE
	ret

.true:
	mov rax, TRUE
	ret

endp
;}
