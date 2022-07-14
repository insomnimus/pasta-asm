param (
	[parameter()]
	[validateSet("clang", "lld-link", "link")]
	$linker = "link"
)

$version = "0.1"

if(-not (get-command -ea ignore fasm)) {
	write-error "the ``fasm`` command is not found"
	return
}

if(-not (get-command -ea ignore cargo)) {
	write-error "the ``cargo`` command is not found
if you don't want to install rust, you can compile the initial and feature-poor version of pasta that only works with notepad by running:
	``fasm pasta_basic.asm pasta.exe``"
	return
}

if(-not (get-command -ea ignore $linker)) {
	write-error "could not locate the linker specified with the -linker option ($linker)
if you don't want to use the newer version, you can compile the feature-poor but pure-assembly version with:
	``fasm pasta_basic.asm pasta.exe``"
	return
}

push-location $PSScriptRoot

$libraries = "kernel32", "user32", "psapi", "bcrypt", "advapi32" # "legacy_stdio_definitions"

fasm pasta.asm pasta.obj

if($lastExitCode -ne 0) {
	pop-location
	write-host "note: are you missing the fasm include folder in the `$INCLUDE env variable?"
	return
}

write-host "building the rust components..."
cargo build --release -q --manifest-path ./ini/Cargo.toml --target x86_64-pc-windows-msvc

if($lastExitCode) {
	write-host "note: is cargo up to date?"
	pop-location
	return
}

$ini = "./ini/target/x86_64-pc-windows-msvc/release/ini.lib"
write-host "linking objects..."

switch -wildcard ($linker) {
	"clang" {
		clang -O3 pasta.obj $ini -o pasta.exe ($libraries | % { "-l", "$_.lib" })
		break
	}
	"*link" {
		&$linker pasta.obj $ini msvcrt.lib ($libraries | % { "$_.lib" }) `
			/out:pasta.exe /stack:4096 /subsystem:console "/version:$version" /debug:none /dynamicbase /highEntropyVA /largeAddressAware /NoLogo /ignore:4078
		break
	}
	default { throw "impossible branch" }
}

if($lastExitCode -ne 0) {
	write-host "note: are you not in an x64 native tools command prompt (or powershell)?"
} else {
	write-host "successfully built the executable ($pwd\pasta.exe)"
}

pop-location
