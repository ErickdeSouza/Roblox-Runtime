# Running Cordial from Windows with WSLg

Cordial does **not** run natively on Windows. The Android engine is an ELF
library loaded by Cordial's Linux runtime and depends on Linux/glibc and the
System V x86-64 ABI. For Windows-hosted development and testing, this guide runs
the existing Linux app inside WSL 2 and displays its GTK window through WSLg.
The launcher, runtime, Unix-socket control channel, and profile data all remain
inside Linux; this is not a Windows port.

## Requirements

- Windows 11, or a supported Windows 10 version with WSLg.
- WSL 2 and an initialized Linux distribution. Ubuntu 24.04 is the tested
  target for Cordial's documented GTK/libadwaita minimums; WSL execution itself
  has not yet been validated on this machine.
- Rust stable via rustup, Git, Clang, CMake, GTK 4.12+, libadwaita 1.5+,
  pkg-config, and the development dependencies listed in
  [install from source](install.md#from-source).

Install WSL and initialize Ubuntu from an elevated PowerShell if needed:

```powershell
wsl --install -d Ubuntu-24.04
wsl --update
```

Complete Ubuntu's first-run user setup, then install the native build
dependencies inside that distribution:

```bash
sudo apt update
sudo apt install build-essential clang cmake pkg-config git \
    libgtk-4-dev libadwaita-1-dev libpipewire-0.3-dev zlib1g-dev
```

Install Rust stable using [rustup](https://rustup.rs/). In PowerShell, ensure
the repository origin is configured. The helper clones the checkout and its
pinned submodules into the WSL Linux filesystem on first launch. If the
repository is private, configure GitHub authentication inside WSL first.
For example, after installing GitHub CLI in the distribution, run
`gh auth login` and `gh auth setup-git`.

## Build and launch

From the Windows checkout, run:

```powershell
.\tools\windows\run-wsl.ps1
```

The first run clones the Git origin and pinned submodules to
`~/src/Roblox-Runtime`, builds the workspace in
`~/.cache/cordial-wsl/target`, and starts `cordial-shell` through WSLg. Both
source and build output stay in the Linux filesystem: Bionic contains header
paths that differ only by letter case, which cannot be represented reliably by
the default case-insensitive Windows filesystem. Keeping Linux and Windows
Cargo artifacts separate also avoids cross-target cache collisions.

Edit the Linux checkout using VS Code's WSL support (`code ~/src/Roblox-Runtime`
from Ubuntu), or push changes from the Windows checkout and use `-Update` to
fast-forward the WSL checkout before launching. `-Update` never resets local
changes; Git refuses the update if the WSL checkout is dirty.

To select a distribution, pass its WSL name:

```powershell
.\tools\windows\run-wsl.ps1 -Distribution Ubuntu-24.04
```

To import and run a local APK, or pass normal launcher arguments:

```powershell
.\tools\windows\run-wsl.ps1 -ApkPath "J:\Downloads\base.apk"
.\tools\windows\run-wsl.ps1 -NoBuild -AppArgs @('--diagnostics')
.\tools\windows\run-wsl.ps1 -Update
```

Use `-LinuxRepoPath` to choose another checkout path; it must be on the WSL
Linux filesystem, absolute or start with `~/` (not under `/mnt/c`, `/mnt/j`,
or another mounted Windows drive).

The default build includes the workspace's default features. WebView and VR
features are not enabled by this helper. Profile/build data is stored in the
WSL distribution, not in the native Windows Cordial data directory. WSLg GPU
rendering, audio behavior and game performance still need validation on real
Windows/WSL hardware.

## Scope and limitations

- This is a Windows development/test route, not a native `.exe` or Windows
  installer.
- Install/setup errors from WSL, GPU passthrough, WSLg, sound and controller
  handling are separate from the direct Windows ABI/ELF blockers recorded in
  [the feasibility assessment](analysis/windows-runtime-feasibility.md).
- Flatpak builds and publication are currently paused; this helper does not
  build or install a Flatpak.
