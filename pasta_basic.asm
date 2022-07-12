format PE64 console
entry start

include "win64wxp.inc"

section ".idata" import data readable writeable ;{
	library \
		kernel32, "kernel32.dll",\
		user32, "user32.dll",\
		psapi, "psapi.dll",\
		msvcrt, "msvcrt.dll"

	import msvcrt, wprintf, "wprintf_s"

	include "api/kernel32.inc"
	include "api/user32.inc"

	import psapi,\
		GetModuleFileNameExW, "GetModuleFileNameExW"
;}

text fix du
define PTR QWORD
define nil 0

macro jif op1*, cond*, op2*, location* {
	cmp op1, op2
	j#cond location
}

section ".bss" data readable writeable ;{
	N_COMMAND text "notepad.exe", 0
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
	include "str.inc"
	include "sys.inc"
	include "io.inc"

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

	proc find_notepad uses rbx rsi rdi, out_hwnd:PTR , out_handle:PTR ;{
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

			jif rax, e, 0, .continue
			mov rsi, rax
			invoke GetModuleFileNameExW, rax, nil, rdi, 512
			jif eax, e, 0, .continue

			fastcall str_make_lower, rdi ; make it lowercase
			fastcall str_ends_with, rdi, "notepad.exe"
			jif eax, e, 0, .continue
			; it is notepad
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

	proc spawn_notepad uses rbx rdi, out_hwnd:PTR , out_handle:PTR ;{
		local proc_info:PROCESS_INFORMATION
		mov [out_hwnd], rcx
		mov [out_handle], rdx

		lea rdi, qword [proc_info]
		try invoke CreateProcessW,\
			nil,\ ; module name
			N_COMMAND,\ ; the command line
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
		; wait for notepad window
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

	proc get_notepad out_hwnd:PTR , out_handle:PTR ;{
		mov qword [out_hwnd], rcx
		mov qword [out_handle], rdx

		fastcall find_notepad, qword [out_hwnd], qword [out_handle]
		jif rax, ne, FALSE, .return
		fastcall spawn_notepad, qword [out_hwnd], qword [out_handle]
		.return: ret
	endp
	;}

	proc send_text uses rbx rsi, hwnd:QWORD, str:PTR ;{
		mov rbx, rcx
		mov rsi, rdx

		invoke FindWindowExW, rbx, 0, "Edit", nil
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
	proc get_text_data uses rdi, out_str:PTR ;{
		mov rdi, rcx

		fastcall is_stdin_tty
		jif al, e, FALSE, .read_stdin

		fastcall get_clip_data
		jif rax, e, nil, .err_no_clip
		mov qword [rdi], rax
		mov rax, FALSE
		ret

	.read_stdin:
		fastcall read_stdin, rdi
		mov rax, TRUE
		ret

	.err_no_clip:
		fastcall exit_with, "no clipboard data is available", 4
		ret
	endp
	;}

	start: ;{
	sub rsp, 8
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

		; First get the text.
		lea rdi, qword [data]
		fastcall get_text_data, rdi
		mov byte [is_piped], al

		; Get the notepad window.
		lea rsi, [n_hwnd]
		lea rdi, [n_handle]
		fastcall get_notepad, rsi, rdi

		; may not be necessary but doesn't hurt
		invoke WaitForInputIdle, qword [rdi], 2000
		try invoke SetForegroundWindow, qword [rsi]

		; Now send the text to notepad.
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
		try invoke HeapFree, <invoke GetProcessHeap>, 0, qword [data]

	.exit:
		mov eax, dword [exit_code]
		ret
	endp
	;}
;}
