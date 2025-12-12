#![feature(c_variadic)]

use std::{default::Default, panic::catch_unwind};

use depict::{graph_drawing::{
    frontend::{dom::{draw, Drawing}, dioxus::DEFAULT_CSS},
    frontend::dioxus::{render, as_data_svg}
}};

use dioxus::{prelude::*};

use futures::StreamExt;
use indoc::indoc;

use tracing::{event, Level};

// ============================================================================
// FEATURE FLAGS - Change these to enable/disable features
// ============================================================================
const ENABLE_STATUS_TRACKING: bool = true;      // Status labels (Ready, Processing, Error)
const ENABLE_TIMEOUT_DETECTION: bool = true;    // 5-second timeout for processing
const ENABLE_HISTORY: bool = true;              // Undo/Redo functionality
const ENABLE_TEST_CONTROLS: bool = true;        // Debug test controls panel

// Conditional imports based on features
#[cfg(any(
    all(feature = "timeout", not(feature = "no-timeout")),
    all(not(feature = "no-timeout"), ENABLE_TIMEOUT_DETECTION)
))]
use std::time::Duration;

#[cfg(any(
    all(feature = "timeout", not(feature = "no-timeout")),
    all(not(feature = "no-timeout"), ENABLE_TIMEOUT_DETECTION)
))]
use gloo_timers::future::TimeoutFuture;

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
// FEATURE-SPECIFIC DATA STRUCTURES
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

pub fn app(cx: Scope<AppProps>) -> Element {

    // Core state (always present)
    let model = use_state(&cx, || String::from(PLACEHOLDER));
    let drawing = use_state(&cx, || draw(PLACEHOLDER.into()).unwrap());
    
    // Feature: Status Tracking
    let status = if ENABLE_STATUS_TRACKING {
        Some(use_state(&cx, || AppStatus::Ready))
    } else {
        None
    };
    
    // Feature: Test Controls
    let test_config = if ENABLE_TEST_CONTROLS {
        Some(use_state(&cx, || TestConfig::default()))
    } else {
        None
    };
    
    // Feature: History/Undo
    let (history, history_index) = if ENABLE_HISTORY {
        let hist = use_state(&cx, || {
            vec![HistoryEntry {
                model: String::from(PLACEHOLDER),
                drawing: draw(PLACEHOLDER.into()).unwrap(),
            }]
        });
        let idx = use_state(&cx, || 0usize);
        (Some(hist), Some(idx))
    } else {
        (None, None)
    };

    // Processing coroutine with conditional features
    let drawing_client = use_coroutine(&cx, |mut rx: UnboundedReceiver<String>| {
        to_owned![drawing, status, model, test_config, history, history_index];
        async move {
            while let Some(current_model) = rx.next().await {
                
                // Set processing status if enabled
                if ENABLE_STATUS_TRACKING {
                    if let Some(ref status) = status {
                        status.set(AppStatus::Processing);
                    }
                }
                
                // Get test config if enabled
                let config = if ENABLE_TEST_CONTROLS {
                    test_config.as_ref().map(|tc| tc.get().clone())
                } else {
                    None
                };
                
                // Process with or without timeout
                let result = if ENABLE_TIMEOUT_DETECTION {
                    #[cfg(any(
                        all(feature = "timeout", not(feature = "no-timeout")),
                        all(not(feature = "no-timeout"), ENABLE_TIMEOUT_DETECTION)
                    ))]
                    {
                        let timeout = TimeoutFuture::new(5_000);
                        
                        let process_future = async {
                            // Test mode: simulate slow processing
                            if let Some(ref cfg) = config {
                                if cfg.simulate_slow {
                                    log::info!("TEST MODE: Simulating slow processing ({}ms)", cfg.delay_ms);
                                    TimeoutFuture::new(cfg.delay_ms).await;
                                }
                                
                                if cfg.simulate_lockup {
                                    log::warn!("TEST MODE: Simulating lockup");
                                    loop {
                                        TimeoutFuture::new(100).await;
                                    }
                                }
                            }
                            
                            if current_model.trim().is_empty() {
                                Ok(Ok(Drawing::default()))
                            } else {
                                catch_unwind(|| draw(current_model.clone()))
                            }
                        };
                        
                        futures::select! {
                            nodes = process_future.fuse() => Some(nodes),
                            _ = timeout.fuse() => None,
                        }
                    }
                    
                    #[cfg(not(any(
                        all(feature = "timeout", not(feature = "no-timeout")),
                        all(not(feature = "no-timeout"), ENABLE_TIMEOUT_DETECTION)
                    )))]
                    {
                        // Fallback if timeout feature not available
                        let nodes = if current_model.trim().is_empty() {
                            Ok(Ok(Drawing::default()))
                        } else {
                            catch_unwind(|| draw(current_model.clone()))
                        };
                        Some(nodes)
                    }
                } else {
                    // No timeout - process directly
                    let nodes = if current_model.trim().is_empty() {
                        Ok(Ok(Drawing::default()))
                    } else {
                        catch_unwind(|| draw(current_model.clone()))
                    };
                    Some(nodes)
                };
                
                // Handle result
                match result {
                    Some(nodes) => {
                        match nodes {
                            Ok(Ok(drawing_nodes)) => {
                                drawing.set(drawing_nodes.clone());
                                
                                if ENABLE_STATUS_TRACKING {
                                    if let Some(ref status) = status {
                                        status.set(AppStatus::Ready);
                                    }
                                }
                                
                                // Add to history if enabled
                                if ENABLE_HISTORY {
                                    if let (Some(ref hist), Some(ref hist_idx)) = (&history, &history_index) {
                                        let mut h = hist.get().clone();
                                        h.push(HistoryEntry {
                                            model: current_model.clone(),
                                            drawing: drawing_nodes,
                                        });
                                        if h.len() > 10 {
                                            h.remove(0);
                                        }
                                        hist.set(h.clone());
                                        hist_idx.set(h.len() - 1);
                                    }
                                }
                            },
                            Ok(Err(draw_err)) => {
                                if ENABLE_STATUS_TRACKING {
                                    if let Some(ref status) = status {
                                        let error_msg = format!("Diagram compilation error: {:?}", draw_err);
                                        status.set(AppStatus::Error(error_msg));
                                    }
                                }
                            },
                            Err(panic_err) => {
                                let panic_info = if let Some(s) = panic_err.downcast_ref::<&'static str>() {
                                    s.to_string()
                                } else if let Some(s) = panic_err.downcast_ref::<String>() {
                                    s.clone()
                                } else {
                                    "Unknown panic".to_string()
                                };
                                log::error!("Panic: {}", panic_info);
                                
                                if ENABLE_STATUS_TRACKING {
                                    if let Some(ref status) = status {
                                        status.set(AppStatus::Error(format!("Internal Panic: {}", panic_info)));
                                    }
                                }
                            },
                        }
                    },
                    None => {
                        // Timeout occurred
                        log::error!("Processing timeout!");
                        if ENABLE_STATUS_TRACKING {
                            if let Some(ref status) = status {
                                status.set(AppStatus::Timeout);
                            }
                        }
                    }
                }
            }
        }
    });

    // UI rendering
    let nodes = render(cx, drawing.get().clone());
    let viewbox_width = drawing.viewbox_width;
    let data_svg = as_data_svg(drawing.get().clone(), true);
    let syntax_guide = depict::graph_drawing::frontend::dioxus::syntax_guide(cx)?;
    
    // Determine status label and style
    let (status_label, label_style) = if ENABLE_STATUS_TRACKING {
        if let Some(ref status) = status {
            match status.get() {
                AppStatus::Ready => ("Enter your model below:", "color: black;"),
                AppStatus::Processing => ("Processing...", "color: orange; font-weight: bold;"),
                AppStatus::Timeout => ("TIMEOUT: Processing took too long", "color: red; font-weight: bold;"),
                AppStatus::Error(_) => ("ERROR: Check your syntax", "color: red; font-weight: bold;"),
            }
        } else {
            ("Enter your model below:", "color: black;")
        }
    } else {
        ("Enter your model below:", "color: black;")
    };
    
    // Check undo/redo availability
    let (can_undo, can_redo) = if ENABLE_HISTORY {
        if let (Some(ref hist), Some(ref hist_idx)) = (&history, &history_index) {
            let idx = *hist_idx.get();
            (idx > 0, idx < hist.get().len() - 1)
        } else {
            (false, false)
        }
    } else {
        (false, false)
    };

    cx.render(rsx!{
        div {
            class: "main_editor",
            div {
                // Status Label (if enabled)
                if ENABLE_STATUS_TRACKING {
                    rsx! {
                        div {
                            style: "{label_style}",
                            status_label
                        }
                    }
                }
                
                // Test Controls (if enabled)
                if ENABLE_TEST_CONTROLS {
                    if let Some(ref tc) = test_config {
                        rsx! {
                            div {
                                style: "padding: 10px; background-color: #f0f0f0; border: 1px solid #ccc; margin-bottom: 10px;",
                                details {
                                    summary {
                                        style: "font-weight: bold; cursor: pointer;",
                                        "🧪 Test Controls"
                                    }
                                    div {
                                        style: "padding: 10px;",
                                        
                                        div {
                                            style: "margin-bottom: 5px;",
                                            label {
                                                input {
                                                    r#type: "checkbox",
                                                    checked: "{tc.simulate_slow}",
                                                    onchange: move |e| {
                                                        let mut config = tc.get().clone();
                                                        config.simulate_slow = e.value.parse().unwrap_or(false);
                                                        tc.set(config);
                                                    }
                                                }
                                                " Simulate Slow Processing ({tc.delay_ms}ms)"
                                            }
                                        }
                                        
                                        div {
                                            style: "margin-bottom: 5px; margin-left: 20px;",
                                            label {
                                                "Delay (ms): "
                                                input {
                                                    r#type: "range",
                                                    min: "500",
                                                    max: "5000",
                                                    step: "500",
                                                    value: "{tc.delay_ms}",
                                                    disabled: "{!tc.simulate_slow}",
                                                    oninput: move |e| {
                                                        let mut config = tc.get().clone();
                                                        config.delay_ms = e.value.parse().unwrap_or(2000);
                                                        tc.set(config);
                                                    }
                                                }
                                                " {tc.delay_ms}ms"
                                            }
                                        }
                                        
                                        div {
                                            style: "margin-bottom: 5px;",
                                            label {
                                                input {
                                                    r#type: "checkbox",
                                                    checked: "{tc.simulate_lockup}",
                                                    onchange: move |e| {
                                                        let mut config = tc.get().clone();
                                                        config.simulate_lockup = e.value.parse().unwrap_or(false);
                                                        tc.set(config);
                                                    }
                                                }
                                                " Simulate Lockup (triggers timeout)"
                                            }
                                        }
                                        
                                        if tc.simulate_slow || tc.simulate_lockup {
                                            rsx! {
                                                div {
                                                    style: "color: orange; font-style: italic; margin-top: 10px;",
                                                    "⚠️ Test mode active"
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // History Controls (if enabled)
                if ENABLE_HISTORY {
                    if let (Some(ref hist), Some(ref hist_idx)) = (&history, &history_index) {
                        rsx! {
                            div {
                                style: "margin-bottom: 10px; display: flex; gap: 10px;",
                                button {
                                    disabled: "{!can_undo}",
                                    onclick: move |_| {
                                        if can_undo {
                                            let new_index = hist_idx.get().saturating_sub(1);
                                            hist_idx.set(new_index);
                                            let entry = &hist.get()[new_index];
                                            model.set(entry.model.clone());
                                            drawing.set(entry.drawing.clone());
                                            if let Some(ref status) = status {
                                                status.set(AppStatus::Ready);
                                            }
                                        }
                                    },
                                    "⬅️ Undo"
                                }
                                button {
                                    disabled: "{!can_redo}",
                                    onclick: move |_| {
                                        if can_redo {
                                            let new_index = *hist_idx.get() + 1;
                                            hist_idx.set(new_index);
                                            let entry = &hist.get()[new_index];
                                            model.set(entry.model.clone());
                                            drawing.set(entry.drawing.clone());
                                            if let Some(ref status) = status {
                                                status.set(AppStatus::Ready);
                                            }
                                        }
                                    },
                                    "➡️ Redo"
                                }
                                span {
                                    style: "color: #666; font-size: 0.9em; align-self: center;",
                                    "History: {hist_idx.get() + 1}/{hist.get().len()}"
                                }
                            }
                        }
                    }
                }
                
                // Text Editor
                div {
                    textarea {
                        style: "box-sizing: border-box; width: calc(100% - 2em); border-width: 1px; border-color: #000;",
                        rows: "10",
                        autocomplete: "off",
                        "autocapitalize": "off",
                        autofocus: "true",
                        spellcheck: "false",
                        oninput: move |e| {
                            event!(Level::TRACE, "INPUT");
                            model.set(e.value.clone());
                            drawing_client.send(e.value.clone());
                        },
                        "{model}"
                    }
                }
                
                // Footer
                div {
                    style: "display: flex; flex-direction: row; justify-content: space-between;",
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
                                details {
                                    summary {
                                        style: "font-size: 0.875rem; line-height: 1.25rem; --tw-text-opacity: 1; color: rgba(156, 163, 175, var(--tw-text-opacity));",
                                        "Licenses",
                                    },
                                    div {
                                        depict::licenses::LICENSES.dirs().map(|dir| {
                                            let path = dir.path().display();
                                            cx.render(rsx!{
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
                                                            cx.render(rsx!{
                                                                details {
                                                                    key: "{file_path:?}",
                                                                    style: "white-space: pre;",
                                                                    summary {
                                                                        "{file_path:?}"
                                                                    }
                                                                    "{file_contents}"
                                                                }
                                                            })
                                                        })
                                                    }
                                                }
                                            })
                                        })
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        // DRAWING
        div {
            class: "content",
            div {
                style: "position: relative; width: {viewbox_width}px; margin-left: auto; margin-right: auto; border-width: 1px; border-color: #000;",
                nodes
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