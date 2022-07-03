pushd $PSScriptRoot

gci -recurse -file `
| where { $_.extension -eq ".asm" -or $_.extension -eq ".inc" } `
| foreach {
	$data = cat $_
	$new = $data | join-string -separator "`n" { $_.trimEnd() }
	if($new -ne ($data | join-string -separator "`n")) {
		"$new`n" | out-file -encoding utf8 -NoNewLine -literalPath $_
		write-host $_.name
	}
}

popd
