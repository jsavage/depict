use std::ffi::{CStr, CString};
use std::os::raw::c_char;

/// Compile a depict model and return SVG as a C string.
///
/// Caller owns the returned string and must free it.
#[no_mangle]
pub extern "C" fn depict_render_svg(input: *const c_char) -> *mut c_char {
    if input.is_null() {
        return std::ptr::null_mut();
    }

    let c_str = unsafe { CStr::from_ptr(input) };
    let model = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    let drawing = match depict::graph_drawing::frontend::dom::draw(model.to_string()) {
        Ok(d) => d,
        Err(_) => return std::ptr::null_mut(),
    };

    let svg = depict::graph_drawing::frontend::dioxus::as_data_svg(drawing, false);

    CString::new(svg).unwrap().into_raw()
}

/// Free a string returned by depict_render_svg
#[no_mangle]
pub extern "C" fn depict_free_string(s: *mut c_char) {
    if s.is_null() {
        return;
    }
    unsafe {
        drop(CString::from_raw(s));
    }
}
