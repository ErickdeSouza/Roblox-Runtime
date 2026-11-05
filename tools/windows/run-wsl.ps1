[CmdletBinding()]
param(
    [string]$Distribution,
    [string]$LinuxRepoPath = '~/src/Roblox-Runtime',
    [string]$ApkPath,
    [switch]$Update,
    [switch]$NoBuild,
    [string[]]$AppArgs = @()
)

$ErrorActionPreference = 'Stop'

$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wsl) {
    throw 'wsl.exe was not found. Install WSL 2 and a Linux distribution first.'
}

$windowsRepo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$remote = & git -C $windowsRepo remote get-url origin
if ($LASTEXITCODE -ne 0) {
    throw "Could not read the checkout's Git origin: $windowsRepo"
}
$remote = ($remote | Out-String).Trim()
$remote = $remote -replace '^git@github\.com:', 'https://github.com/'
$remote = $remote -replace '^ssh://git@github\.com/', 'https://github.com/'
if ([string]::IsNullOrWhiteSpace($remote)) {
    throw "The checkout has no Git origin to clone into WSL: $windowsRepo"
}

$distroArgs = @()
if (-not [string]::IsNullOrWhiteSpace($Distribution)) {
    $distroArgs = @('--distribution', $Distribution)
}

$probeArgs = $distroArgs + @('--exec', 'true')
$probeOutput = & $wsl.Source @probeArgs 2>&1
if ($LASTEXITCODE -ne 0) {
    $detail = (($probeOutput | Out-String) -replace "`0", '').Trim()
    throw "Could not start a WSL distribution. Install and initialize WSL 2 first. $detail"
}

$linuxApk = ''
if (-not [string]::IsNullOrWhiteSpace($ApkPath)) {
    $linuxApk = (Resolve-Path $ApkPath).Path
}

$build = if ($NoBuild) { '0' } else { '1' }
$update = if ($Update) { '1' } else { '0' }
$bash = @'
set -eu
repo_input=$1
build=$2
apk=$3
clone_url=$4
update=$5
shift 5

case "$repo_input" in
    "~") repo="$HOME" ;;
    "~/"*) repo="$HOME/${repo_input#\~/}" ;;
    /*) repo="$repo_input" ;;
    *)
        printf 'LinuxRepoPath must be an absolute path or start with ~/.\n' >&2
        exit 2
        ;;
esac

case "$repo" in
    /mnt/*)
        printf 'LinuxRepoPath must be on the WSL Linux filesystem, not a mounted Windows drive.\n' >&2
        exit 2
        ;;
esac

if [ ! -e "$repo/.git" ]; then
    if [ -d "$repo" ] && [ -n "$(ls -A "$repo")" ]; then
        printf 'Linux repository path exists but is not a Git checkout: %s\n' "$repo" >&2
        exit 2
    fi
    mkdir -p "$(dirname "$repo")"
    git clone --recurse-submodules "$clone_url" "$repo"
else
    if [ "$update" = 1 ]; then
        git -C "$repo" pull --ff-only
    fi
    git -C "$repo" submodule update --init --recursive
fi

target="$HOME/.cache/cordial-wsl/target"

if [ ! -f "$repo/third_party/mcpelauncher-linker/bionic/linker/linker.cpp" ]; then
    printf '%s\n' "Cordial's native linker submodule is missing." \
        "Check the GitHub remote and initialize the checkout's submodules." >&2
    exit 2
fi

cd "$repo"
if [ "$build" = 1 ]; then
    CARGO_TARGET_DIR="$target" cargo build --workspace --release
fi

for binary in cordial-shell cordial-run; do
    if [ ! -x "$target/release/$binary" ]; then
        printf 'Missing %s; run this script without -NoBuild first.\n' "$target/release/$binary" >&2
        exit 2
    fi
done

export CORDIAL_DEV_CONTROL="${CORDIAL_DEV_CONTROL:-1}"
export CORDIAL_SYSTEM_PLUGIN_DIR="${CORDIAL_SYSTEM_PLUGIN_DIR:-$repo/plugins}"
if [ -n "$apk" ]; then
    case "$apk" in
        [A-Za-z]:\\*) apk=$(wslpath -u -a "$apk") ;;
    esac
    export CORDIAL_APK="$apk"
fi
exec "$target/release/cordial-shell" "$@"
'@

$runArgs = $distroArgs + @(
    '--exec', 'bash', '-lc', $bash, 'cordial-wsl',
    $LinuxRepoPath, $build, $linuxApk, $remote, $update
) + $AppArgs
& $wsl.Source @runArgs
exit $LASTEXITCODE
