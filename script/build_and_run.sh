#!/bin/bash
set -euo pipefail
package_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$package_dir"
build_configuration=debug
mode=run
while [[ $# -gt 0 ]]; do
  case "$1" in
    --release) build_configuration=release; shift ;;
    --build-only) mode=build-only; shift ;;
    --debug|--logs|--telemetry|--verify) mode="${1#--}"; shift; break ;;
    *) break ;;
  esac
done
swift build --quiet -c "$build_configuration"
binary_dir="$(swift build -c "$build_configuration" --show-bin-path)"
dist_dir="$package_dir/dist"
app="$dist_dir/Native Lyrics Demo.app"
mkdir -p "$dist_dir"
stage_root="$(mktemp -d "${TMPDIR:-/tmp}/native-lyrics-demo.XXXXXX")"
staged="$stage_root/Native Lyrics Demo.app"
trap 'rm -rf "$stage_root"' EXIT
if [[ -d "$app" ]]; then
  # Only stop this exact development executable, never a same-named player.
  running_pid="$(pgrep -f "^${app}/Contents/MacOS/NativeLyricsDemo( |$)" || true)"
  if [[ -n "$running_pid" ]]; then
    kill $running_pid
    for _ in {1..20}; do
      pgrep -f "^${app}/Contents/MacOS/NativeLyricsDemo( |$)" >/dev/null || break
      sleep 0.05
    done
  fi
fi
mkdir -p "$staged/Contents/MacOS" "$staged/Contents/Resources"
cp -X "$binary_dir/NativeLyricsDemo" "$staged/Contents/MacOS/"
cp -X "$package_dir/script/Info.plist" "$staged/Contents/Info.plist"
for resource in "$package_dir/Sources/NativeLyricsDemo/Resources"/*.ttml; do
  [[ ! -f "$resource" ]] || cp -X "$resource" "$staged/Contents/Resources/"
done
for bundle in "$binary_dir"/*.bundle; do [[ ! -d "$bundle" ]] || cp -RX "$bundle" "$staged/Contents/Resources/"; done
for fixture in song.ttml audio.m4a fixture.json; do
  if [[ -f "$package_dir/.local/$fixture" ]]; then cp -X "$package_dir/.local/$fixture" "$staged/Contents/Resources/"; fi
done
# Stage outside the Finder-watched source tree, then atomically move the
# signed bundle into dist. This avoids a metadata race on nested SwiftPM
# resource bundles while still leaving the familiar dist path for the demo.
xattr -cr "$staged" 2>/dev/null || true
signed=0
for _ in {1..8}; do
  if codesign --force --sign - "$staged"; then
    signed=1
    break
  fi
  # Finder/FileProvider may race the cleanup by restoring its bundle marker;
  # retry after the service has finished its metadata pass.
  xattr -cr "$staged" 2>/dev/null || true
  sleep 0.05
done
if [[ "$signed" != 1 ]]; then exit 1; fi
# Verify before Finder has a chance to reattach presentation metadata after
# the app is opened.
codesign --verify --deep --strict "$staged"
rm -rf "$app"
mv "$staged" "$app"
codesign --verify --deep --strict "$app"
case "$mode" in
  build-only)
    ;;
  run)
    /usr/bin/open -n "$app" --args "$@"
    ;;
  debug)
    lldb -- "$app/Contents/MacOS/NativeLyricsDemo" "$@"
    ;;
  logs)
    /usr/bin/open -n "$app" --args "$@"
    /usr/bin/log stream --info --style compact --predicate 'process == "NativeLyricsDemo"'
    ;;
  telemetry)
    /usr/bin/open -n "$app" --args "$@"
    /usr/bin/log stream --info --style compact --predicate 'subsystem == "org.example.NativeLyricsDemo"'
    ;;
  verify)
    /usr/bin/open -n "$app" --args "$@"
    for _ in {1..20}; do
      pgrep -f "^${app}/Contents/MacOS/NativeLyricsDemo( |$)" >/dev/null && break
      sleep 0.1
    done
    pgrep -f "^${app}/Contents/MacOS/NativeLyricsDemo( |$)" >/dev/null
    ;;
  *)
    echo "usage: $0 [--release] [--build-only|--debug|--logs|--telemetry|--verify] [demo arguments]" >&2
    exit 2
    ;;
esac
echo "$app"
