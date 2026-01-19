# Depict — Rust FFI + Flutter (Linux)

This repository contains **Depict**, a Rust-based graph renderer exposed via **C-compatible FFI** and consumed by a **Flutter (Linux) desktop application**.
The current baseline focuses on **Linux-only**, with a reproducible Docker-based build and test workflow.

---

## Architecture Overview

### High-level flow

```
Flutter (Dart UI)
   ↓ dart:ffi
DepictFfiBindings (Dart)
   ↓ C ABI
Rust FFI layer (ffi crate)
   ↓ internal API
Rust graph renderer → SVG
```

### Key components

| Component         | Path                         | Purpose                            |
| ----------------- | ---------------------------- | ---------------------------------- |
| Core Rust library | `src/`                       | Graph parsing and SVG generation   |
| Rust FFI wrapper  | `ffi/`                       | `extern "C"` ABI for Dart          |
| Flutter app       | `depict_flutter/`            | Linux desktop UI                   |
| Docker tooling    | `docker-*.sh`                | Reproducible Linux builds          |
| Copy script       | `scripts/copy_depict_ffi.sh` | Installs `.so` into Flutter bundle |

---

## Rust FFI Design

### Exported API (Rust → Dart)

The Rust FFI exposes a **minimal, stable C ABI**:

```c
char* depict_render_svg(const char* input);
void  depict_free_string(char* ptr);
```

**Ownership rules**

* Dart allocates input string
* Rust allocates output SVG string
* Dart **must** call `depict_free_string`

This avoids allocator mismatches and keeps lifetime rules explicit.

---

## Flutter Integration

### Dart bindings

* File: `depict_flutter/lib/ffi/depict_ffi_bindings.dart`
* Uses `dart:ffi` + generated bindings
* Dynamically loads `libdepict_ffi.so`

### Runtime library lookup (Linux)

At runtime the Flutter app looks for:

```
build/linux/x64/{debug|release}/bundle/lib/libdepict_ffi.so
```

The Docker scripts ensure the shared library is copied into this location.

---

## Docker-based Workflow (Recommended)

All commands below are run **from the repo root**.

### 1. Clean everything

```bash
./docker-dev.sh clean
```

(If you ever get permission issues, re-run with `sudo`.)

---

### 2. Build Rust + Flutter (Linux)

```bash
./dbuild-flutter.sh
```

This does the following:

1. Builds Rust `libdepict_ffi.so` (release)
2. Builds Flutter Linux bundle
3. Copies `libdepict_ffi.so` into:

   ```
   depict_flutter/build/linux/x64/release/bundle/lib/
   depict_flutter/libdepict_ffi.so   (for tests)
   ```

---

### 3. Run tests (inside Docker)

```bash
./docker-flutter.sh test
```

Tests include:

* FFI library load test
* SVG rendering test
* Writes `test_output.svg` for inspection

---

### 4. Run the Flutter app (Linux desktop)

```bash
./docker-flutter.sh run -d linux
```

> Note: This requires an X11 display.
> If running over SSH, ensure `$DISPLAY` and X forwarding are set.

---

## Running the built binary directly

After a successful build:

```bash
depict_flutter/build/linux/x64/release/bundle/depict_flutter
```

If `libdepict_ffi.so` cannot be found, re-run:

```bash
./scripts/copy_depict_ffi.sh
```

---

## Output behavior

* SVG is rendered live in the Flutter UI
* SVG is also saved to:

  ```
  output.svg
  ```
* Status line shows the absolute path

---

## Known limitations (current baseline)

* Linux-only
* No Windows / macOS support yet
* SVG styling is renderer-dependent

  * Browser rendering is authoritative
* No CI configured yet

---

## Git hygiene

Generated artifacts are excluded via `.gitignore`, including:

* Rust `target/`
* Flutter `build/`, `.dart_tool/`
* Logs and SVG outputs

---

## Next steps (planned)

* CI (Rust + Flutter)
* SVG styling fixes (box fill, arrowheads)
* AppImage / `.deb` packaging
* Windows and macOS support

---

## License

TBD

---

## Maintainer notes

This repo intentionally prioritizes:

* Explicit FFI ownership rules
* Reproducible Docker builds
* Minimal magic in Flutter runtime loading

If something breaks, start with:

```bash
./docker-dev.sh clean
./dbuild-flutter.sh
./docker-flutter.sh test
```

That sequence should always get you back to a known-good state.
