use std::{
	collections::HashMap,
	env,
	ffi::OsStr,
	fs,
	os::windows::ffi::OsStrExt,
	process,
	ptr,
};

use clap::Parser;
use configparser::ini::Ini;

type WinStr = *const u16;

#[repr(C)]
pub struct Editor {
	path: WinStr,
	basename: WinStr,
	edit: WinStr,
	no_reuse: u32,
	cp: u32,
}

#[derive(Parser)]
#[command(version)]
struct Args {
	/// Path to the pasta config file
	#[arg(short, long)]
	config: Option<String>,
	/// A section name from the config file to use
	#[arg(short, long, default_value = "default")]
	editor: String,
	/// Do not reuse an existing window, always spawn a new editor
	#[arg(short, long)]
	new: bool,
}

impl Editor {
	fn new(path: &str, edit: &str, cp: u32, no_reuse: bool) -> Result<Self, String> {
		let basename = path
			.rsplit(|c: char| c == '\\' || c == '/')
			.next()
			.ok_or_else(|| format!("path does not point to a file ({path})"))?
			.to_lowercase();

		let mut path = OsStr::new(path).encode_wide().collect::<Vec<_>>();
		path.push(0);
		let path = Box::into_raw(path.into_boxed_slice()) as WinStr;

		Ok(Self {
			no_reuse: if no_reuse { 1 } else { 0 },
			cp,
			path,
			basename: to_win(&basename),
			edit: to_win(edit),
		})
	}
}

#[link(name = "kernel32")]
extern "system" {
	fn GetProcessHeap() -> isize;
	fn HeapFree(h_heap: isize, h_flags: i32, ptr: isize) -> i32;
	fn WideCharToMultiByte(
		codepage: u32,
		dwFlags: u32,
		lpWideCharStr: WinStr,
		cchWideChar: i32,
		lpMultiByteStr: *mut u8,
		cbMultiByte: i32,
		lpDefaultChar: *const u8,
		lpUsedDefaultChar: *mut i32,
	) -> i32;
}

impl Drop for Editor {
	fn drop(&mut self) {
		unsafe {
			free_editor(self as _);
		}
	}
}

/// ## Safety
/// The memory needs to be allocated.
#[no_mangle]
pub unsafe extern "system" fn free_editor(e: *mut Editor) -> i32 {
	let h = GetProcessHeap();
	let free = |s: WinStr| HeapFree(h, 0, s as _);
	let n = free((*e).path);
	if n == 0 {
		return n;
	}
	let n = free((*e).basename);
	if n == 0 {
		return n;
	}
	free((*e).edit)
}

fn to_win(s: &str) -> WinStr {
	let mut buf = Vec::with_capacity(s.len() + 1);
	buf.extend(s.encode_utf16());
	buf.push(0);
	Box::into_raw(buf.into_boxed_slice()) as _
}

fn parse_args() -> Result<Editor, String> {
	let e = Args::parse();

	let edit = e.config.or_else(|| {
		let mut p = env::current_exe()
			.ok()?;
			if !p.set_extension("ini") || !p.is_file() {
				None
			} else {
				p.into_os_string().into_string().ok()
			}
	});
	let edit = match edit {
		None => Editor::new("notepad.exe", "Edit", 1200, e.new)?,
		Some(p) => {
			let mut ini = Ini::new();
			let data =
				fs::read_to_string(&p).map_err(|e| format!("read {p}: {e}"))?;
			ini.read(data)
				.map_err(|e| format!("(config): {e}\n-- file: {p}"))?;
			{
				let map = ini.get_mut_map();
				map.entry("default".into()).or_insert_with(|| {
					HashMap::from_iter([
						("cp".into(), Some("1200".into())),
						("path".into(), Some("notepad.exe".into())),
						("edit".into(), Some("Edit".into())),
					])
				});
			}
			let key = e.editor;

			let map = ini.get_map_ref();
			let map = map.get(&key).ok_or_else(|| {
				format!("(config) no editor section named {key} found\n-- path: {p}")
			})?;

			let get = |field: &str| {
				map.get(field).and_then(|o| o.as_deref()).ok_or_else(|| {
					format!("(config) missing required value [{key}].{field}\n-- path: {p}")
				})
			};

			Editor::new(
				get("path")?,
				get("edit")?,
				get("cp")?.parse::<u32>().map_err(|_| {
					format!("(config) the `cp` key must be an unsigned integer\n-- path: {p}")
				})?,
				e.new,
			)?
		}
	};

	Ok(edit)
}

unsafe fn valid_cp(cp: u32) -> bool {
	const DUMMY_STR: WinStr = [65, 0].as_ptr();
	cp == 1200
		|| 0 != WideCharToMultiByte(
			cp,
			0,
			DUMMY_STR,
			2,
			ptr::null_mut(),
			0,
			ptr::null(),
			ptr::null_mut(),
		)
}

/// ## Safety
/// The `out` parameter must be valid to write.
#[no_mangle]
pub unsafe extern "system" fn get_editor_config(out: *mut Editor) {
	// println!("size: {}, align: {}", std::mem::size_of::<Editor>(),
	// std::mem::align_of::<Editor>());
	match parse_args() {
		Ok(x) if valid_cp(x.cp) => out.write(x),
		Ok(x) => {
			eprintln!(
				"error: the code page identifier {} is not a valid code page",
				x.cp
			);
			process::exit(2);
		}
		Err(e) => {
			eprintln!("error: {e}");
			process::exit(1);
		}
	}
}
