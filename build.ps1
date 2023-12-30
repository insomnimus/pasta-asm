param (
	[parameter()]
	[validateSet("clang", "lld-link", "link")]
	$linker = "link",
	[Parameter()]
	[switch] $buildStd,
	[string] $out = "$PSScriptRoot\pasta.exe",
	[string[]] $rustflags
)

$out = [IO.Path]::GetFullPath($out, $PWD.ProviderPath)
$version = "0.2"

if(-not (get-command -ea ignore fasm)) {
	write-error "the ``fasm`` command is not found"
	exit 1
}

if(-not (get-command -ea ignore cargo)) {
	write-error "the ``cargo`` command is not found
if you don't want to install rust, you can compile the initial and feature-poor version of pasta that only works with notepad by running:
	``fasm pasta_basic.asm pasta.exe``"
	exit 1
}

if(-not (get-command -ea ignore $linker)) {
	write-error "could not locate the linker specified with the -linker option ($linker)
if you don't want to use the newer version, you can compile the feature-poor but pure-assembly version with:
	``fasm pasta_basic.asm pasta.exe``"
	exit 1
}

push-location $PSScriptRoot

$libraries = "kernel32", "user32", "psapi", "bcrypt", "advapi32", "ntdll"

fasm pasta.asm pasta.obj
if($lastExitCode -ne 0) {
	pop-location
	"note: are you missing the fasm include folder in the `$INCLUDE env variable?"
	exit 1
}

"building the rust components..."
$unstableArgs = $null
$toolchain = $null
if($buildStd) {
	$unstableArgs = "-Zbuild-std=core,alloc,std,panic_abort", "-Zbuild-std-features=panic_immediate_abort"
	$toolchain = "+nightly"
}

cargo $toolchain rustc -qr $unstableArgs --manifest-path ./ini/Cargo.toml --target x86_64-pc-windows-msvc -- -Copt-level=2 -Ccodegen-units=1 $rustflags
if($lastExitCode) {
	"note: is cargo up to date?"
	pop-location
	exit 1
}

$ini = "./ini/target/x86_64-pc-windows-msvc/release/ini.lib"
"linking objects..."

switch -wildcard ($linker) {
	"clang" {
		clang pasta.obj $ini -O2 -o $out ($libraries | foreach-object { "-l", "$_.lib" })
		break
	}
	"*link" {
		&$linker pasta.obj $ini msvcrt.lib ($libraries | foreach-object { "$_.lib" }) `
			/NoLogo "/out:$out" /subsystem:console "/version:$version" `
			/dynamicbase /highEntropyVA /largeAddressAware /ignore:4078 `
			/debug:none /OPT:REF /OPT:ICF /stack:4096
		break
	}
	default { throw "impossible branch" }
}

if($lastExitCode -ne 0) {
	"note: are you not in an x64 native tools command prompt (or powershell)?"
	exit 1
} else {
	"successfully built the executable ($out)"
}

pop-location
