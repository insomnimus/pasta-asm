if(-not (get-command -ea ignore fasm)) {
	write-error "the ``fasm`` command is not found"
	return
}
if(-not (get-command -ea ignore cargo)) {
	write-error "the ``cargo`` command is not found
if you don't want to install rust, you can compile the initial and feature-poor version of pasta that only works with notepad by running:
	``fasm pasta_basic.asm pasta.exe -d config=release``"
	return
}

if(-not (get-command -ea ignore clang)) {
	write-error "this project requires ``clang`` for linking and it's not found
if you don't want to install clang, you can compile the initial and feature-poor version of pasta that only works with notepad by running:
	``fasm pasta_basic.asm pasta.exe -d config=release``"
	return
}

push-location $PSScriptRoot

$libraries = "kernel32", "user32", "psapi", "legacy_stdio_definitions", "bcrypt", "advapi32"

fasm pasta.asm pasta.obj -d config=release

if($lastExitCode -ne 0) {
	pop-location
	write-host "note: are you missing the fasm include folder in the `$INCLUDE env variable?"
	return
}

write-host "building the rust part"
cargo build --release -q --manifest-path ./ini/Cargo.toml

if($lastExitCode) {
	write-host "note: is cargo up to date?"
	push-location
	return
}

write-host "linking objects..."

clang -O3 pasta.obj ./ini/target/release/ini.lib -o pasta.exe ($libraries | % { "-l", "$_.lib" })

if($lastExitCode -ne 0) {
	write-host "note: are you not in an x64 native tools command prompt (or powershell)?"
} else {
	write-host "successfully built the executable ($pwd\pasta.exe)"
}

pop-location
