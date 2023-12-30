macro try command*& {
	command
	cmp rax, 0
	je err_exit
}

err_exit: ;{
	mov rbp, rsp
	sub rsp, 32
	lea rbx, qword [rbp - 8]

	invoke FormatMessageW,\
		FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER,\
		0,\
		<invoke GetLastError>,\
		LANG_NEUTRAL,\
		rbx,\
		0, 0

	fastcall write_error, qword [rbx]
	invoke LocalFree, rbx
	invoke ExitProcess, 1

	add rsp, 32
	mov rbp, rsp
	ret
;}

proc exit_with uses rbx rsi, msg:PTR, code:DWORD ;{
	mov rsi, rcx
	mov ebx, edx
	fastcall write_error, rsi
	invoke ExitProcess, ebx
	ret
endp
;}
