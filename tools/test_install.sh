#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

BIN_DIR="$TMP_DIR/bin"
LOG_DIR="$TMP_DIR/logs"
HOME_DIR="$TMP_DIR/home"
mkdir -p "$BIN_DIR" "$LOG_DIR" "$HOME_DIR"

cat >"$BIN_DIR/xcodebuild" <<EOF
#!/bin/bash
set -euo pipefail
printf '%s\n' "\$*" >"$LOG_DIR/xcodebuild_args.txt"
derived_data_path=""
previous=""
for arg in "\$@"; do
    if [[ "\$previous" == "-derivedDataPath" ]]; then
        derived_data_path="\$arg"
        break
    fi
    previous="\$arg"
done
if [[ -z "\$derived_data_path" ]]; then
    echo "missing -derivedDataPath in xcodebuild invocation" >&2
    exit 1
fi
app_dir="\$derived_data_path/Build/Products/Release/azooKeyMac.app/Contents"
mkdir -p "\$app_dir/Resources/en.lproj"
cat >"\$app_dir/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>local.atelierarith.inputmethod.azooKeyMac</string>
</dict>
</plist>
PLIST
exit 0
EOF

cat >"$BIN_DIR/codesign" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >"$LOG_DIR/codesign_args.txt"
exit 0
EOF

cat >"$BIN_DIR/killall" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >"$LOG_DIR/killall_args.txt"
exit 0
EOF

cat >"$BIN_DIR/lsregister" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >"$LOG_DIR/lsregister_args.txt"
exit 0
EOF

chmod +x "$BIN_DIR/xcodebuild" "$BIN_DIR/codesign" "$BIN_DIR/killall" "$BIN_DIR/lsregister"

set +e
(
    cd "$REPO_ROOT"
    HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" LSREGISTER="$BIN_DIR/lsregister" ./install.sh --ignore-lint >/dev/null 2>&1
)
status=$?
set -e

if [[ $status -ne 0 ]]; then
    echo "expected install.sh default local install flow to complete in the stubbed test environment"
    exit 1
fi

if ! grep -q -- "-configuration Release" "$LOG_DIR/xcodebuild_args.txt"; then
    echo "expected install.sh default to build Release for local install"
    exit 1
fi

if ! grep -q -- " CODE_SIGNING_ALLOWED=NO" "$LOG_DIR/xcodebuild_args.txt"; then
    echo "expected install.sh default to disable code signing during xcodebuild"
    exit 1
fi

if ! grep -q -- " CODE_SIGNING_REQUIRED=NO" "$LOG_DIR/xcodebuild_args.txt"; then
    echo "expected install.sh default to skip required code signing during xcodebuild"
    exit 1
fi

if grep -q -- "-allowProvisioningUpdates" "$LOG_DIR/xcodebuild_args.txt"; then
    echo "did not expect default local install to request provisioning updates"
    exit 1
fi

app_dst="$HOME_DIR/Library/Input Methods/azooKeyMac.app"
if [[ ! -d "$app_dst" ]]; then
    echo "expected install.sh default to copy the app into ~/Library/Input Methods"
    exit 1
fi

if ! grep -q -- "--entitlements ./azooKeyMac/azooKeyMac.entitlements" "$LOG_DIR/codesign_args.txt"; then
    echo "expected install.sh default to ad-hoc sign with project entitlements"
    exit 1
fi

if ! grep -q -- "$app_dst" "$LOG_DIR/lsregister_args.txt"; then
    echo "expected install.sh default to register the local input method app"
    exit 1
fi

if ! grep -q -- "TextInputMenuAgent cfprefsd" "$LOG_DIR/killall_args.txt"; then
    echo "expected install.sh default to refresh input source agents"
    exit 1
fi

echo "install.sh defaults to local user install"
