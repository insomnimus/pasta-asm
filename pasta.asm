format MS64 COFF

include "win64wxp.inc"

UTF16 = 1200

invoke fix fastcall
text fix du
PTR fix QWORD
define nil 0

macro externs [ext] {
	yes = 0
	match name \as ident, ext \{
	extrn \`name as ident:QWORD
	yes = 1
	\}

	if ~ yes
		extrn ext:QWORD
	end if
	yes = 0
}

macro jif op1*, cond*, op2*, location* {
	cmp op1, op2
	j#cond location
}

section ".bss" data readable writeable ;{
		struct Editor ;{
		path dq 0
		basename dq 0
		edit dq 0
		no_reuse dd 0 ; actually just a byte but we have to pad
		cp dd ?
	ends
	;}

; config Editor 0, 0, 0, 0, 0
config Editor
	N_STARTUP_INFO STARTUPINFO \
		sizeof.STARTUPINFO,\ ; cb
		0,\ ; lpReserved
		0,\ ; lpDesktop
		0,\ ; lpTitle,
		0,\ ; dwX
		0,\ ; dwY
		0,\ ; dwXSize
		0,\ ; dwYSize
		0,\ ; dwXCountChars
		0,\ ; dwYCountChars
		0,\ ; dwFillAttribute
		0,\ ; dwFlags
		0,\ ; wShowWindow
		0,\ ; cbReserved2
		0,\ ; lpReserved2
		0,\ ; hStdInput
		0,\ ; hStdOutput
		0 ; hStdError
;}

section ".text" code readable executable ;{
	public main

	include "str.inc"
	include "sys.inc"
	include "io.inc"

	;; ini externs
	externs free_editor, get_editor_config

	;; CRT dependencies (not necessary unless we want to debug with println)
	; externs wprintf_s as wprintf, _CRT_INIT

	;; windows dependencies
	externs \ ;{
		GetConsoleCP,\
		CloseHandle,\
		GetLastError,\
		SendMessageW,\
		FormatMessageW,\
		ReadFile, WriteFile,\
		GetFileType,\
		FindWindowExW, EnumWindows, GetWindowThreadProcessId, IsWindowVisible, GetWindow, GetTopWindow, SetForegroundWindow,\
		OpenClipboard, CloseClipboard, GetClipboardData, IsClipboardFormatAvailable,\
		GetModuleFileNameExW,\
		GetConsoleOutputCP,\
		WaitForInputIdle,\
		HeapAlloc, HeapReAlloc, GetProcessHeap, HeapFree,\
		LocalFree,\
		OpenProcess, ExitProcess,\
		CreateProcessW,\
		GetStdHandle,\
		WideCharToMultiByte, MultiByteToWideChar
	;}

	struct HwndAndPid ;{
		pid dq ? ; actually dword
		hwnd dq ?
	ends
	;}

	proc get_clip_data ;{
		invoke IsClipboardFormatAvailable, CF_UNICODETEXT
		jif eax, e, 0, .return_none
		try invoke OpenClipboard, nil
		try invoke GetClipboardData, CF_UNICODETEXT
		ret

	.return_none:
	mov rax, nil
		ret
	endp
	;}

	proc find_editor uses rbx rsi rdi, out_hwnd:PTR , out_handle:PTR ;{
	local pid:DWORD
		mov [out_hwnd], rcx
		mov [out_handle], rdx

		try invoke GetTopWindow, 0
		mov rbx, rax ; rbx stores current hwnd
		invoke HeapAlloc, <invoke GetProcessHeap>, 0, 1024
		mov rdi, rax ; rdi stores alloc

		.loop:
			jif rbx, e, 0, .return_none
			invoke IsWindowVisible, rbx
			jif eax, e, 0, .continue
			lea rax, qword [pid] ; load pid pointer
			invoke GetWindowThreadProcessId, rbx, rax
			jif eax, e, 0, .continue
			mov eax, dword [pid] ; read pid
			jif eax, e, 0, .continue

			; open process to get its path
			invoke OpenProcess,\
				PROCESS_QUERY_INFORMATION or PROCESS_VM_READ,\
				0, eax

			jif rax, e, FALSE, .continue
			mov rsi, rax
			invoke GetModuleFileNameExW, rax, nil, rdi, 512
			jif eax, e, FALSE, .continue

			fastcall str_make_lower, rdi ; make it lowercase
			fastcall str_ends_with, rdi, qword [config.basename]
			jif eax, e, FALSE, .continue
			; it is the editor
			mov rax, [out_hwnd]
			mov qword [rax], rbx
			mov rax, [out_handle]
			mov [rax], rsi
			try invoke HeapFree, <invoke GetProcessHeap>, 0, rdi
			mov rax, TRUE
			ret

		.continue:
			invoke GetWindow, rbx, GW_HWNDNEXT
			mov rbx, rax
			jmp .loop

	.return_none:
		mov rax, [out_hwnd]
		mov qword [rax], 0
		mov rax, [out_handle]
		mov qword [rax], 0
		try invoke HeapFree, <invoke GetProcessHeap>, 0, rdi
		mov rax, FALSE
		ret
	endp
	;}

	proc spawn_editor uses rbx rdi, out_hwnd:PTR , out_handle:PTR ;{
		local proc_info:PROCESS_INFORMATION
		mov [out_hwnd], rcx
		mov [out_handle], rdx

		lea rdi, qword [proc_info]
		try invoke CreateProcessW,\
			nil,\ ; module name
			qword [config.path],\ ; the command line
			nil,\ ; process attributes
			nil,\ ; thread attributes
			FALSE,\ ; don't inherit handles
			nil,\ ; creation flags
			nil,\ ; the env
			nil,\ ; the starting directory
			N_STARTUP_INFO,\ ; the startup info
			rdi ; the out process info

		mov rax, qword [proc_info.hProcess]
		mov rbx, qword [out_handle]
		mov qword [rbx], rax
		; wait for the window
		invoke WaitForInputIdle, rax, 2000

		xor rax, rax
		mov ebx, dword [proc_info.dwProcessId]
		fastcall get_hwnd_from_pid, ebx

		mov rbx, qword [out_hwnd]
		mov qword [rbx], rax
		ret
	endp
	;}

	proc get_hwnd_from_pid uses rdi, pid:DWORD ;{
		local target:HwndAndPid
		mov dword [target.pid], ecx
		mov qword [target.hwnd], 0

		lea rdi, qword [target]
		invoke EnumWindows, enum_windows_callback, rdi

		mov rax, qword [target.hwnd]
		ret
	endp
	;}

	proc enum_windows_callback uses rdi, hwnd:QWORD, lparam:PTR ;{
		local out:DWORD

		mov dword [out], 0
		mov qword [hwnd], rcx
		mov qword [lparam], rdx

		lea rdi, qword [out]
		invoke GetWindowThreadProcessId, qword [hwnd], rdi

		; load lparam.pid
		mov rax, qword [lparam] ; load address
		mov rax, qword [rax] ; load the pid
		jif eax, ne, dword [out], .not_it
		; It's the pid we're looking for but the window needs to be visible.
		invoke IsWindowVisible, qword [hwnd]
		jif eax, e, FALSE, .not_it
		; found it, set target hwnd
		mov rax, qword [hwnd]
		mov rdi, qword [lparam]
		mov qword [rdi + 8], rax
		mov rax, FALSE
		ret

	.not_it:
		mov rax, TRUE
		ret
	endp
	;}

	proc get_editor out_hwnd:PTR , out_handle:PTR ;{
		mov qword [out_hwnd], rcx
		mov qword [out_handle], rdx

		jif dword [config.no_reuse], ne, FALSE, .spawn
		fastcall find_editor, qword [out_hwnd], qword [out_handle]
		jif rax, ne, FALSE, .return
		.spawn: fastcall spawn_editor, qword [out_hwnd], qword [out_handle]
		.return: ret
	endp
	;}

	proc send_text uses rbx rsi, hwnd:QWORD, str:PTR ;{
		mov rbx, rcx
		mov rsi, rdx

		invoke FindWindowExW, rbx, 0, qword [config.edit], nil
		jif rax, e, 0, .not_found
		invoke SendMessageW, rax, WM_SETTEXT, 0, rsi
		mov rax, TRUE
		ret

	.not_found:
		mov rax, FALSE
		ret
	endp
	;}

	;; Returns TRUE if the data came from stdin.
	proc get_text_data uses rsi rdi, out_str:PTR ;{
		local tmp_str:PTR

		mov rdi, rcx

		fastcall is_stdin_tty
		jif al, e, FALSE, .read_stdin

		fastcall get_clip_data
		jif rax, e, nil, .err_no_clip
		fastcall encode_data, rax, rdi, FALSE
		mov rax, FALSE
		ret

	.read_stdin:
		lea rsi, qword [tmp_str]
		fastcall read_stdin, rsi
		fastcall encode_data, qword [rsi], rdi, TRUE
		mov rax, TRUE
		ret

	.err_no_clip:
		fastcall exit_with, "no clipboard data is available", 4
		ret
	endp
	;}

	proc encode_data uses rbx rsi rdi, in_str:PTR, out_str:PTR, free_old:BYTE ;{
		mov rsi, rcx
		mov rdi, rdx
		mov bl, r8b

		jif dword [config.cp], e, UTF16, .same_encoding

		fastcall wide_to_other, rsi, rdi, dword [config.cp]
		jif bl, e, FALSE, .return
		try invoke HeapFree, <invoke GetProcessHeap>, 0, rsi
		ret
	.free_data:
		try invoke HeapFree, <invoke GetProcessHeap>, 0, rsi
		ret
	.same_encoding:
		mov qword [rdi], rsi
	.return: ret
	endp
	;}

	main: ;{
	sub rsp, 8
	; invoke _CRT_INIT
		fastcall start_fn
		invoke ExitProcess, eax
		add rsp, 8
		ret
	;}

	proc start_fn;{
		local exit_code:DWORD
		local n_hwnd:QWORD
		local n_handle:QWORD
		local data:PTR
		local is_piped:BYTE

		mov dword [exit_code], 0

		invoke get_editor_config, config
		; First get the text.
		lea rdi, qword [data]
		fastcall get_text_data, rdi
		mov byte [is_piped], al

		; Get the editor window.
		lea rsi, [n_hwnd]
		lea rdi, [n_handle]
		fastcall get_editor, rsi, rdi

		; may not be necessary but doesn't hurt
		invoke WaitForInputIdle, qword [rdi], 2000
		try invoke SetForegroundWindow, qword [rsi]

		; Now send the text to the config.
		fastcall send_text, qword [n_hwnd], qword [data]
		jif al, ne, FALSE, .return
		fastcall write_error, "could not locate the edit window"
		mov dword [exit_code], 8

	.return:
		; Close the process handle.
		try invoke CloseHandle, qword [n_handle]

		; If stdin was piped, free the memory, else close clipboard.
		mov al, byte [is_piped]
		jif al, ne, FALSE, ..free_data
		invoke CloseClipboard ; This errors for some reason
		jmp .exit

	..free_data:
		try invoke free_editor, config
		try invoke HeapFree, <invoke GetProcessHeap>, 0, qword [data]

	.exit:
		mov eax, dword [exit_code]
		ret
	endp
	;}
;}
