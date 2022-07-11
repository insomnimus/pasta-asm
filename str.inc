;; unused - needs msvcrt.dll (wprintf -> wprintf_s)
macro println fmt*, [arg] {
	common
	if ~ (fmt eqtype "")
		display "error: first argument to println must be a string literal"
		err
	end if

		local .fmt, .p
		jmp .p
		.fmt text fmt, 10, 0
		.p: invoke wprintf, .fmt, arg
}

proc write_error uses rbx rsi rdi, str:PTR ;{
	local out_str:PTR
	local err_str:PTR

	mov rsi, rcx

	invoke GetStdHandle, STD_ERROR_HANDLE
	mov rbx, rax

	lea rdi, qword [err_str]
	fastcall _wide_to_console, "error: ", rdi
	invoke WriteFile, rbx, qword [err_str], eax, nil, 0

	lea rdi, qword [out_str]
	fastcall _wide_to_console, rsi, rdi
	invoke WriteFile, rbx, qword [rdi], eax, nil, 0

	; Free allocated memory.
	invoke HeapFree, <invoke GetProcessHeap>, 0, qword [err_str]
	invoke HeapFree, <invoke GetProcessHeap>, 0, qword [out_str]

	ret
endp
;}

proc strlen uses rdi, string:PTR ;{
	mov rdi, rcx
	mov rcx, 0FFFFFFFFFFFFFFFFh
	xor rax, rax
	cld
	repne scasw
	xor  rcx, 0FFFFFFFFFFFFFFFFh
	dec rcx
	mov rax, rcx

	ret
endp
;}

proc str_eq uses rsi rdi rbx, s1:PTR, s2:PTR ;{
	mov rsi, rcx
	mov rdi, rdx
	fastcall strlen, rsi
	mov rbx, rax
	fastcall strlen, rdi
	cmp rax, rbx
	jne .return_false

	cld
	lea rcx, [rbx + 1] ; load len + the null word
	repe cmpsw
	cmp rcx, 0
	jne .return_false
	mov rax, 1
	ret

.return_false:
	mov rax, 0
	ret
endp
;}

proc char_make_lower uses rax rdx rdi rbx, char_ptr:PTR ;{
xor rbx, rbx
	mov bx, word [rcx]
	lea dx, word [rbx - 'A']
	mov ax, bx
	or bx, 20h
	cmp dx, 25
	cmovb ax, bx
	mov word [rcx], ax
	ret
endp
;}

proc str_make_lower uses rsi rdi, str:PTR ;{
	mov rsi, rcx
	fastcall strlen, rsi
	cmp rax, 0
	je .return
	add rax, rax
	lea rdi, [rax + rsi - 2]

	.loop:
		cmp rsi, rdi
		ja .return
		fastcall char_make_lower, rsi
		add rsi, 2
		jmp .loop
.return: ret
endp
;}

proc str_ends_with uses rbx rsi rdi, str:PTR, suffix:PTR ;{
	mov rsi, rcx
	mov rdi, rdx

	fastcall strlen, rsi
	mov rbx, rax
	fastcall strlen, rdi
	cmp rax, rbx
	ja .return_false
	sub rbx, rax ; str.len - suffix.len
	times 2 add rsi, rbx ; multiply by 2 for wide

	fastcall str_eq, rsi, rdi
	ret
.return_false:
	xor rax, rax
	ret
endp
;}

proc _wide_to_console_old uses rbx rsi rdi, str:PTR, out_str:PTR ;{
	local input_len:QWORD
	local out_len:DWORD

	mov rsi, rcx
	mov rdi, rdx
	fastcall strlen, rsi
	mov qword [input_len], rax

	invoke GetConsoleOutputCP
	mov rbx, rax

	invoke WideCharToMultiByte,\
		ebx,\ ; the code page
		0,\ ; flags
		rsi,\ ; input
		dword [input_len],\ ; length
		nil,\ ; output
		0,\ ; output size
	0, 0

	; Allocate enough heap to hold the string.
	mov dword [out_len], eax
	invoke HeapAlloc, <invoke GetProcessHeap>, HEAP_ZERO_MEMORY, eax
	mov qword [rdi], rax ; Store allocation.

		invoke WideCharToMultiByte,\
		ebx,\ ; the code page
		0,\ ; flags
		rsi,\ ; input
		dword [input_len],\ ; length
		qword [rdi],\ ; output
		dword [out_len],\ ; output size
	0, 0

	mov eax, dword [out_len]
	ret
endp
;}

proc _wide_to_console uses rsi rdi, str:PTR, out_str:PTR ;{
	mov rsi, rcx
	mov rdi, rdx
	fastcall wide_to_other, rsi, rdi, <invoke GetConsoleCP>
	ret
endp
;}

proc wide_to_other uses rbx rsi rdi, str:PTR, out_str:PTR, cp:DWORD ;{
	local input_len:QWORD
	local out_len:DWORD

	mov rsi, rcx
	mov rdi, rdx
	mov ebx, r8d
	fastcall strlen, rsi
	mov qword [input_len], rax

	invoke WideCharToMultiByte,\
		ebx,\ ; the code page
		0,\ ; flags
		rsi,\ ; input
		dword [input_len],\ ; length
		nil,\ ; output
		0,\ ; output size
	0, 0

	; Allocate enough heap to hold the string.
	mov dword [out_len], eax
	invoke HeapAlloc, <invoke GetProcessHeap>, HEAP_ZERO_MEMORY, eax
	mov qword [rdi], rax ; Store allocation.

		invoke WideCharToMultiByte,\
		ebx,\ ; the code page
		0,\ ; flags
		rsi,\ ; input
		dword [input_len],\ ; length
		qword [rdi],\ ; output
		dword [out_len],\ ; output size
	0, 0

	mov eax, dword [out_len]
	ret
endp
;}
