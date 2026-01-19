use std::ffi::{CStr, CString};
use std::os::raw::c_char;

fn normalize_svg_data_url(s: &str) -> Option<String> {
    const PREFIX: &str = "data:image/svg+xml;utf8,";

    let svg = s.strip_prefix(PREFIX)?;

    // URL-decode (very small and safe)
    urlencoding::decode(svg).ok().map(|s| s.into_owned())
}

// It seems that the input string must end with a semi-colon so this makes sure this happens
fn normalize_input(mut s: String) -> String {
    if !s.ends_with('\n') && !s.ends_with(';') {
        s.push('\n');
    }
    s
}


#[no_mangle]
pub extern "C" fn depict_render_svg(input: *const c_char) -> *mut c_char {
    use std::panic::{catch_unwind, AssertUnwindSafe};

    let result = catch_unwind(AssertUnwindSafe(|| -> Option<*mut c_char> {
        if input.is_null() {
            return None;
        }

        let c_str = unsafe { CStr::from_ptr(input) };
        let model = match c_str.to_str() {
            Ok(s) => normalize_input(s.to_string()),
            Err(_) => return None,
        };

        let drawing = match depict::graph_drawing::frontend::dom::draw(model) {
            Ok(d) => d,
            Err(_) => return None,
        };

        let data_svg =
            depict::graph_drawing::frontend::dioxus::as_data_svg(drawing, false);

        eprintln!("RAW DATA SVG:\n{}", data_svg);

        let svg = match normalize_svg_data_url(&data_svg) {
            Some(s) => s,
            None => return None,
        };

        match CString::new(svg) {
            Ok(s) => Some(s.into_raw()),
            Err(_) => None,
        }
    }));

    match result {
        Ok(Some(ptr)) => ptr,
        _ => std::ptr::null_mut(), // panic OR logical failure
    }
}




#[no_mangle]
pub extern "C" fn depict_free_string(s: *mut c_char) {
    if s.is_null() {
        return;
    }
    unsafe {
        drop(CString::from_raw(s));
    }
}


