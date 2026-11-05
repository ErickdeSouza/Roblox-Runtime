# Windows runtime feasibility

## Decision

**No-go for a direct native Windows build of the existing runtime.** The current
runtime is not a portable Rust application with a few Linux-only UI calls. Its
core execution model loads an Android ELF shared object into the same process
as an AOSP Bionic linker and answers that object's imports with a mixture of
Cordial implementations and Linux host libraries. Recompiling the launcher for
Windows would not make that execution model work.

This is a decision about the existing architecture, not a claim that Windows
support is theoretically impossible. A native port would require a substantial
compatibility/runtime project and a real Roblox-engine proof of concept before
the rest of the application is ported.

## Evidence from this checkout

| Area | Evidence | Consequence |
|---|---|---|
| ELF loading | `cordial-linker-sys/build.rs` builds the AOSP Bionic linker and JNI shims from C++ using Clang. `cordial_runtime::symtab` registers Bionic libraries and host symbols for that linker. | The engine is loaded as ELF code in the Cordial process; it is not launched as a separate Windows executable. |
| Host libc | `cordial-runtime/src/bin/load.rs` labels `--host-libc` as ABI-unsafe and diagnostic-only. `docs/base-evaluation.md` records that Bionic and glibc disagree on layouts including `stat`, `pthread_mutex_t`, `DIR`, `FILE`, and `sigset_t`; the runtime has explicit conversion/shim code for these differences. | Linux libc compatibility is part of the engine boundary, not a replaceable UI dependency. Windows has neither glibc nor the Linux ABI expected by these host calls. |
| Native ABI | The loaded Android x86-64 code and its interfaces use the System V AMD64 calling convention. Windows x64 uses a different calling convention. Host calls, callbacks, and function pointers would need explicit, tested ABI bridges; ordinary C++ linkage is not sufficient. | Even a Windows ELF mapper would not make existing Linux host function pointers safe to call from the engine. |
| OS services | The native code includes Linux/POSIX interfaces such as `unistd.h`, `sys/statvfs.h`, `sys/socket.h`, `dlfcn.h`, and `pthread.h`; `build.rs` links `dl` and `pthread`. Runtime modules also use Linux syscalls and process conventions. | A direct build needs Windows implementations or compatibility shims across the runtime, native code, filesystem, synchronization, process, and library-loading paths. |
| Graphics and desktop | The runtime's Android window is built on GTK/GDK and Wayland/X11. Audio and system integration use Linux backends including PipeWire, PulseAudio/ALSA, D-Bus, and Linux accessibility services. | Replacing the launcher window alone would not bring up the game; rendering, input, audio, dialogs, and system integration need Windows backends too. |
| IPC | `cordial-protocol/src/socket.rs` uses Unix domain sockets, Unix permissions, file descriptors, and `/proc/self/fd`. `cargo check -p cordial-protocol` was run on Windows MSVC and failed on these APIs. | At least this shared boundary needs a platform abstraction and a Windows transport such as named pipes. |
| Build | `cordial-linker-sys/build.rs` links `stdc++`, `z`, `dl`, and `pthread`; native CMake sources assume Linux headers and libraries. `cargo check --workspace` on this Windows machine stops earlier in GTK sys crates because GTK development metadata (`pkg-config`) is unavailable. | The current workspace has no configured Windows-native build path. The GTK failure alone is an environment limitation, but the linker and runtime dependencies are architectural blockers. |

## What a direct native port would require

Before calling a native port viable, a minimal proof of concept must load the
real engine on Windows and pass its relocations, constructors, TLS and JNI
initialization without relying on Linux host libraries. That proof would need
to include, at minimum:

1. A supported ELF mapping/relocation strategy on Windows, including memory
   protection, TLS, and the loader operations the engine expects.
2. Safe System V AMD64-to-Windows x64 bridges for calls in both directions,
   including callbacks and ABI-sensitive/variadic surfaces.
3. Implementations for the required Bionic/Linux library and syscall surfaces,
   instead of forwarding those calls to glibc or the Linux kernel.
4. A Windows graphics/window/input/audio backend and replacements for Linux
   service integrations.
5. A repeatable Windows build and a real-engine smoke test; a Rust-only
   cross-check is not evidence that the game runtime works.

This is significantly larger than adding `cfg(windows)` around the current
shell and should not be treated as a routine portability patch.

## Recommended next decision

For near-term Windows testing, keep the current Linux runtime intact and run it
under WSL2 (using WSLg where applicable). If a native Windows product remains a
hard requirement, first make a separate, isolated experiment for the engine
loader and ABI bridge. Continue to a Windows host-backend port only if that
experiment can load and initialize the real engine; otherwise the viable
Windows route is a Windows-facing launcher that delegates execution to WSL2,
which is a different architecture and needs its own plan.

Windows-specific implementations are not automatically Linux-compatible. The
Linux implementation must remain an explicit backend, selected alongside a
Windows backend behind shared interfaces.

## Validation performed

- `cargo check -p cordial-protocol` on `x86_64-pc-windows-msvc`: failed on
  `std::os::unix`, Unix sockets, POSIX permissions, and `/proc/self/fd`, as
  expected from the current source.
- `cargo check --workspace` on Windows: stopped in GTK sys build scripts because
  `pkg-config` and the GTK development libraries are not installed. This does
  not by itself prove GTK cannot be built on Windows.
