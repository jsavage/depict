#![feature(c_variadic)]

use std::{default::Default, panic::catch_unwind};

use depict::{graph_drawing::{
    frontend::{dom::{draw, Drawing}, dioxus::DEFAULT_CSS},
    frontend::dioxus::{render, as_data_svg}
}};

use dioxus::{prelude::*};

use futures::StreamExt;
use indoc::indoc;

use wasm_bindgen::JsCast;

use tracing::{event, Level};

// ============================================================================
// FEATURE FLAGS - Change these to enable/disable features at compile time
// Set all to false to get back to the original code behavior
// ============================================================================
const ENABLE_STATUS_TRACKING: bool = true;
const ENABLE_TIMEOUT_DETECTION: bool = false;
const ENABLE_HISTORY: bool = false;
const ENABLE_TEST_CONTROLS: bool = false;

// Only import gloo_timers if timeout detection is enabled
#[cfg(all(target_arch = "wasm32"))]
mod timeout_support {
    #[cfg(all(target_arch = "wasm32"))]
    pub use gloo_timers::future::TimeoutFuture;
}

// ============================================================================
// C SHIM FUNCTIONS (unchanged)
// ============================================================================

#[no_mangle]
unsafe extern "C" fn malloc(size: ::std::os::raw::c_ulong) -> *mut ::std::os::raw::c_void {
    use std::alloc::{alloc, Layout};
    let layout = Layout::from_size_align(size as usize + std::mem::size_of::<Layout>(), 16).unwrap();
    let ptr = alloc(layout);
    *(ptr as *mut Layout) = layout;
    (ptr as *mut Layout).offset(1) as *mut ::std::os::raw::c_void
}

#[no_mangle]
unsafe extern "C" fn calloc(count: ::std::os::raw::c_ulong, size: ::std::os::raw::c_ulong) -> *mut ::std::os::raw::c_void {
    use std::alloc::{alloc_zeroed, Layout};
    let layout = Layout::from_size_align((count * size) as usize + std::mem::size_of::<Layout>(), 16).unwrap();
    let ptr = alloc_zeroed(layout);
    *(ptr as *mut Layout) = layout;
    (ptr as *mut Layout).offset(1) as *mut ::std::os::raw::c_void
}

#[no_mangle]
unsafe extern "C" fn realloc(ptr: *mut ::std::os::raw::c_void, size: ::std::os::raw::c_ulong) -> *mut ::std::os::raw::c_void {
    use std::alloc::{realloc, Layout};
    let ptr = (ptr as *mut Layout).offset(-1);
    let layout = *ptr;
    let ptr = realloc(ptr as *mut u8, layout, size as usize + std::mem::size_of::<Layout>());
    *(ptr as *mut Layout) = Layout::from_size_align(size as usize + std::mem::size_of::<Layout>(), 16).unwrap();
    (ptr as *mut Layout).offset(1) as *mut ::std::os::raw::c_void
}

#[no_mangle]
unsafe extern "C" fn free(ptr: *mut ::std::os::raw::c_void) {
    use std::alloc::{dealloc, Layout};
    let ptr = (ptr as *mut Layout).offset(-1);
    let layout = *ptr;
    dealloc(ptr as *mut u8, layout);
}

#[no_mangle]
unsafe extern "C" fn printf(format: *const ::std::os::raw::c_char, mut args: ...) -> ::std::os::raw::c_int {
    let mut s = String::new();
    #[cfg(target_family="wasm")]
    let format = format as *const u8;
    #[cfg(not(target_family="wasm"))]
    let format = format as *const i8;
    let bytes_written = printf_compat::format(
        format,
        args.as_va_list(),
        printf_compat::output::fmt_write(&mut s)
    );
    log::info!("{s}");
    bytes_written
}

#[no_mangle]
unsafe extern "C" fn putchar(c: ::std::os::raw::c_int) -> ::std::os::raw::c_int {
    let c2 = std::char::from_u32(c as u32).unwrap();
    log::info!("{c2}");
    c
}

#[no_mangle]
unsafe extern "C" fn puts(s: *const ::std::os::raw::c_char) -> ::std::os::raw::c_int {
    printf("%s".as_ptr() as *const i8, s)
}

fn now() -> i64 {
    let window = web_sys::window().expect("should have a window in this context");
    let performance = window
        .performance()
        .expect("performance should be available");
    performance.now() as i64
}

#[no_mangle]
unsafe extern "C" fn mach_absolute_time() -> ::std::os::raw::c_longlong {
    now()
}

use osqp_rust_sys::src::src::util::{mach_timebase_info_t, kern_return_t};

#[no_mangle]
unsafe extern "C" fn mach_timebase_info(info: mach_timebase_info_t) -> kern_return_t {
    let info = &mut *info;
    info.numer = 1;
    info.denom = 1;
    0
}

#[no_mangle]
unsafe extern "C" fn dlopen(__path: *const ::std::os::raw::c_char, __mode: ::std::os::raw::c_int) -> *mut ::std::os::raw::c_void {
    todo!()
}

#[no_mangle]
unsafe extern "C" fn dlclose(__handle: *mut ::std::os::raw::c_void) -> ::std::os::raw::c_int {
    todo!()
}

#[no_mangle]
unsafe extern "C" fn dlerror() -> *mut ::std::os::raw::c_char {
    todo!()
}

#[no_mangle]
unsafe extern "C" fn dlsym(
    __handle: *mut ::std::os::raw::c_void,
    __symbol: *const ::std::os::raw::c_char,
) -> *mut ::std::os::raw::c_void {
    todo!()
}

#[no_mangle]
unsafe extern "C" fn sqrt(x: ::std::os::raw::c_double) -> ::std::os::raw::c_double {
    x.sqrt()
}

use osqp_rust_sys::src::lin_sys::lib_handler::__darwin_ct_rune_t;

#[no_mangle]
unsafe extern "C" fn __tolower(_: __darwin_ct_rune_t) -> __darwin_ct_rune_t {
    todo!()
}

#[no_mangle]
unsafe extern "C" fn __toupper(_: __darwin_ct_rune_t) -> __darwin_ct_rune_t {
    todo!()
}

const PLACEHOLDER: &str = indoc!("
    person microwave food: open, start, stop / beep : heat
    person food: stir
");

// ============================================================================
// URL PARAMETER HELPER FUNCTION
// ============================================================================

/// Simple URL encoder that handles common characters
fn encode_url(input: &str) -> String {
    let mut encoded = String::with_capacity(input.len() * 3);
    
    for byte in input.as_bytes() {
        match byte {
            // Unreserved characters (don't need encoding)
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                encoded.push(*byte as char);
            }
            // Everything else gets percent-encoded
            _ => {
                encoded.push_str(&format!("%{:02X}", byte));
            }
        }
    }
    
    encoded
}

/// Simple URL decoder that handles the most common URL-encoded characters
fn decode_url(encoded: &str) -> String {
    let mut decoded = String::with_capacity(encoded.len());
    let mut chars = encoded.chars();
    
    while let Some(c) = chars.next() {
        if c == '%' {
            // Try to decode %XX where XX are hex digits
            let hex: String = chars.by_ref().take(2).collect();
            if hex.len() == 2 {
                if let Ok(byte) = u8::from_str_radix(&hex, 16) {
                    decoded.push(byte as char);
                    continue;
                }
            }
            // If decoding fails, just keep the % and hex chars
            decoded.push('%');
            decoded.push_str(&hex);
        } else if c == '+' {
            // '+' is often used for space in URL encoding
            decoded.push(' ');
        } else {
            decoded.push(c);
        }
    }
    
    decoded
}

/// Extracts the 'input' parameter from the URL query string and decodes it.
/// Returns the decoded string if found, otherwise returns None.
fn get_url_input_parameter() -> Option<String> {
    let window = web_sys::window()?;
    let location = window.location();
    let search = location.search().ok()?;
    
    if search.is_empty() || search == "?" {
        return None;
    }
    
    // Parse query string manually (simple implementation)
    // Format: ?input=encoded_value or ?other=value&input=encoded_value
    let query = search.trim_start_matches('?');
    
    for pair in query.split('&') {
        let mut parts = pair.splitn(2, '=');
        if let (Some(key), Some(value)) = (parts.next(), parts.next()) {
            if key == "input" {
                // URL decode the value
                return Some(decode_url(value));
            }
        }
    }
    
    None
}

// ============================================================================
// FEATURE-SPECIFIC DATA STRUCTURES - only defined if needed
// ============================================================================

#[derive(Clone, PartialEq)]
pub enum AppStatus {
    Ready,
    Processing,
    Timeout,
    Error(String),
}

#[derive(Clone)]
pub struct TestConfig {
    pub simulate_slow: bool,
    pub simulate_lockup: bool,
    pub delay_ms: u32,
}

impl Default for TestConfig {
    fn default() -> Self {
        TestConfig {
            simulate_slow: false,
            simulate_lockup: false,
            delay_ms: 2000,
        }
    }
}

#[derive(Clone)]
pub struct HistoryEntry {
    pub model: String,
    pub drawing: Drawing,
}

// ============================================================================
// MAIN APPLICATION
// ============================================================================

pub struct AppProps {}

#[derive(Clone, Copy, PartialEq)]
enum Tab {
    Editor,
    Diagram,
}

#[allow(unused_variables)]
pub fn app(cx: Scope<AppProps>) -> Element {

    // Determine initial model text: use URL parameter if available, otherwise use placeholder
    let initial_model = get_url_input_parameter().unwrap_or_else(|| String::from(PLACEHOLDER));
    
    // Core state (always present)
    let model = use_state(&cx, || initial_model.clone());
    let drawing = use_state(&cx, || {
        draw(initial_model.clone()).unwrap_or_default()
    });
    
    // Status tracking (conditional)
    let status = if ENABLE_STATUS_TRACKING {
        Some(use_state(&cx, || AppStatus::Ready))
    } else {
        None
    };
    
    // Tab state
    let active_tab = use_state(&cx, || Tab::Editor);
    
    // Keyboard shortcut handler
    let tab_state = active_tab.clone();
    use_effect(&cx, (), move |_| {
        let window = web_sys::window().unwrap();
        let document = window.document().unwrap();
        
        let closure = wasm_bindgen::closure::Closure::wrap(Box::new(move |e: web_sys::KeyboardEvent| {
            if e.alt_key() {
                match e.key().as_str() {
                    "1" => {
                        e.prevent_default();
                        tab_state.set(Tab::Editor);
                    },
                    "2" => {
                        e.prevent_default();
                        tab_state.set(Tab::Diagram);
                    },
                    _ => {}
                }
            }
        }) as Box<dyn FnMut(_)>);
        
        document
            .add_event_listener_with_callback("keydown", closure.as_ref().unchecked_ref())
            .unwrap();
        
        // Keep closure alive
        closure.forget();
        
        async move {}
    });

    // Processing coroutine - complexity hidden inside
    let drawing_client = if ENABLE_STATUS_TRACKING && status.is_some() {
        let status_state = status.as_ref().unwrap().clone();
        use_coroutine(&cx, |mut rx: UnboundedReceiver<String>| {
            to_owned![drawing, status_state];
            async move {
                while let Some(current_model) = rx.next().await {
                    // Update status to Processing
                    status_state.set(AppStatus::Processing);
                    
                    let nodes = if current_model.trim().is_empty() {
                        Ok(Ok(Drawing::default()))
                    } else {
                        catch_unwind(|| draw(current_model.clone()))
                    };
                    
                    match nodes {
                        Ok(Ok(drawing_nodes)) => {
                            drawing.set(drawing_nodes);
                            status_state.set(AppStatus::Ready);
                        },
                        Ok(Err(_)) => {
                            status_state.set(AppStatus::Error("Failed to render diagram".to_string()));
                        },
                        Err(_) => {
                            status_state.set(AppStatus::Error("Rendering panicked".to_string()));
                        }
                    }
                }
            }
        })
    } else {
        use_coroutine(&cx, |mut rx: UnboundedReceiver<String>| {
            to_owned![drawing];
            async move {
                while let Some(current_model) = rx.next().await {
                    let nodes = if current_model.trim().is_empty() {
                        Ok(Ok(Drawing::default()))
                    } else {
                        catch_unwind(|| draw(current_model.clone()))
                    };
                    
                    match nodes {
                        Ok(Ok(drawing_nodes)) => {
                            drawing.set(drawing_nodes);
                        },
                        Ok(Err(_)) | Err(_) => {
                            // Errors are silently ignored when status tracking is disabled
                        }
                    }
                }
            }
        })
    };

    // UI rendering - render nodes for each tab separately
    let viewbox_width = drawing.viewbox_width;
    let data_svg = as_data_svg(drawing.get().clone(), true);
    let syntax_guide = depict::graph_drawing::frontend::dioxus::syntax_guide(cx)?;
    
    // Generate shareable link with current model
    let window = web_sys::window().expect("should have window");
    let location = window.location();
    let base_url = format!(
        "{}//{}{}",
        location.protocol().unwrap_or_default(),
        location.host().unwrap_or_default(),
        location.pathname().unwrap_or_default()
    );
    let encoded_model = encode_url(&model.get());
    let share_url = format!("{}?input={}", base_url, encoded_model);

    let editor_tab_bg = if *active_tab.get() == Tab::Editor { "#fff" } else { "transparent" };
    let editor_tab_border = if *active_tab.get() == Tab::Editor { "2px solid #000" } else { "none" };
    let editor_tab_weight = if *active_tab.get() == Tab::Editor { "bold" } else { "normal" };
    
    let diagram_tab_bg = if *active_tab.get() == Tab::Diagram { "#fff" } else { "transparent" };
    let diagram_tab_border = if *active_tab.get() == Tab::Diagram { "2px solid #000" } else { "none" };
    let diagram_tab_weight = if *active_tab.get() == Tab::Diagram { "bold" } else { "normal" };
    
    // Status indicator text and color
    let (status_text, status_color) = if ENABLE_STATUS_TRACKING && status.is_some() {
        match status.as_ref().unwrap().get() {
            AppStatus::Ready => ("Ready", "#28a745"),
            AppStatus::Processing => ("Processing...", "#ffc107"),
            AppStatus::Timeout => ("Timeout", "#dc3545"),
            AppStatus::Error(ref msg) => (msg.as_str(), "#dc3545"),
        }
    } else {
        ("", "")
    };

    cx.render(rsx!{
        div {
            style: "display: flex; flex-direction: column; height: 100vh;",
            
            // Tab Navigation
            div {
                style: "display: flex; border-bottom: 2px solid #000; background-color: #f0f0f0; align-items: center;",
                button {
                    style: "padding: 0.75rem 1.5rem; border: 1px solid #000; border-bottom: none; background-color: {editor_tab_bg}; margin-bottom: -2px; cursor: pointer; font-size: 1rem; font-weight: {editor_tab_weight}; margin-right: 0.25rem;",
                    onclick: move |_| active_tab.set(Tab::Editor),
                    "Editor (Alt+1)"
                }
                button {
                    style: "padding: 0.75rem 1.5rem; border: 1px solid #000; border-bottom: none; background-color: {diagram_tab_bg}; margin-bottom: -2px; cursor: pointer; font-size: 1rem; font-weight: {diagram_tab_weight};",
                    onclick: move |_| active_tab.set(Tab::Diagram),
                    "Diagram (Alt+2)"
                }
                
                // Status indicator (only shown if status tracking is enabled)
                if ENABLE_STATUS_TRACKING {
                    rsx! {
                        div {
                            style: "margin-left: auto; margin-right: 1rem; padding: 0.5rem 1rem; background-color: {status_color}; color: white; border-radius: 4px; font-size: 0.875rem; font-weight: bold;",
                            "{status_text}"
                        }
                    }
                }
            }
            
            // Editor Tab Content
            if *active_tab.get() == Tab::Editor {
                rsx! {
                    div {
                        style: "flex: 1; overflow: auto; display: flex; flex-direction: column;",
                        div {
                            style: "padding: 1rem; display: flex; flex-direction: column;",
                            div {
                                div {
                                    style: "margin-bottom: 0.5rem;",
                                    "Model"
                                }
                                
                                // Text Editor
                                div {
                                    textarea {
                                        style: "box-sizing: border-box; width: 100%; height: 200px; border-width: 1px; border-color: #000; padding: 0.5rem; font-family: monospace;",
                                        autocomplete: "off",
                                        "autocapitalize": "off",
                                        autofocus: "true",
                                        spellcheck: "false",
                                        oninput: move |e| {
                                            model.set(e.value.clone());
                                            drawing_client.send(e.value.clone());
                                        },
                                        "{model}"
                                    }
                                }
                                
                                // Footer
                                div {
                                    style: "display: flex; flex-direction: row; justify-content: space-between; margin-top: 0.5rem; margin-bottom: 1rem;",
                                    syntax_guide,
                                    div {
                                        details {
                                            style: "display: flex; flex-direction: column; align-self: end; font-size: 0.875rem; line-height: 1.25rem;",
                                            summary {
                                                span { "Tools" }
                                            },
                                            div {
                                                a {
                                                    href: "{data_svg}",
                                                    download: "depict.svg",
                                                    "Export SVG"
                                                }
                                            }
                                            div {
                                                a {
                                                    href: "{share_url}",
                                                    target: "_blank",
                                                    "Share Link"
                                                }
                                            }
                                            div {
                                                details {
                                                    summary {
                                                        style: "font-size: 0.875rem; line-height: 1.25rem; --tw-text-opacity: 1; color: rgba(156, 163, 175, var(--tw-text-opacity));",
                                                        "Licenses",
                                                    },
                                                    div {
                                                        depict::licenses::LICENSES.dirs().map(|dir| {
                                                            let path = dir.path().display();
                                                            rsx!{
                                                                div {
                                                                    key: "{path}",
                                                                    span {
                                                                        style: "font-style: italic; text-decoration: underline;",
                                                                        "{path}"
                                                                    },
                                                                    ul {
                                                                        dir.files().map(|f| {
                                                                            let file_path = f.path();
                                                                            let file_contents = f.contents_utf8().unwrap();
                                                                            rsx!{
                                                                                details {
                                                                                    key: "{file_path:?}",
                                                                                    style: "white-space: pre;",
                                                                                    summary {
                                                                                        "{file_path:?}"
                                                                                    }
                                                                                    "{file_contents}"
                                                                                }
                                                                            }
                                                                        })
                                                                    }
                                                                }
                                                            }
                                                        })
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // DRAWING - flows below controls with relative positioning context
                            div {
                                style: "position: relative; width: {viewbox_width}px; margin-left: auto; margin-right: auto; border-width: 1px; border-color: #000; margin-top: 1rem;",
                                render(cx, drawing.get().clone())
                            }
                        }
                    }
                }
            }
            
            // Diagram Tab Content
            if *active_tab.get() == Tab::Diagram {
                rsx! {
                    div {
                        style: "flex: 1; overflow: auto; background-color: white; padding-top: 2rem;",
                        div {
                            style: "position: relative; width: {viewbox_width}px; margin-left: auto; margin-right: auto; border-width: 1px; border-color: #000;",
                            render(cx, drawing.get().clone())
                        }
                    }
                }
            }
        }
    })
}

fn main() {
    wasm_logger::init(wasm_logger::Config::default());
    console_error_panic_hook::set_once();

    let window = web_sys::window().unwrap();
    let document = window.document().unwrap();
    let head = document.get_elements_by_tag_name("head").item(0).unwrap();
    let style = document.create_element("style").unwrap();
    style.set_inner_html(DEFAULT_CSS);
    head.append_child(&style).unwrap();

    dioxus_web::launch_with_props(
        app,
        AppProps {},
        dioxus_web::Config::new()
    );
}