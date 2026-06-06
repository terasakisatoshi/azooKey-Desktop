#!/bin/bash
set -xe -o pipefail

IGNORE_LINT=false
DRY_RUN=false
INSTALL_MODE=local

LOCAL_APP_NAME="azooKeyMac.app"
LOCAL_APP_DIR="$HOME/Library/Input Methods"
LOCAL_APP_DST="$LOCAL_APP_DIR/$LOCAL_APP_NAME"
LSREGISTER="${LSREGISTER:-/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister}"

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --ignore-lint) IGNORE_LINT=true ;;
        --dry-run) DRY_RUN=true ;;
        --system-install) INSTALL_MODE=system ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [ "$IGNORE_LINT" = false ]; then
    if command -v swiftlint &> /dev/null
    then
        # Fix auto-fixable errors
        swiftlint --fix --format
        # Check other errors
        swiftlint --quiet --strict
    else
        echo "swiftlint could not be found. Please rerun the script as \`./install.sh --ignore-lint\`."
        echo "For contributing azooKey on macOS, we strongly recommend you to install swiftlint"
        echo "To install swiftlint, run \`brew install swiftlint\`"
        exit 1
    fi
else
    echo "Skipping swiftlint checks due to --ignore-lint option."
fi

run_local_install() {
    local build_dir
    build_dir="$(mktemp -d "${TMPDIR:-/tmp}/azookey-local-install.XXXXXX")"
    trap 'rm -rf "$build_dir"' RETURN

    local app_src="$build_dir/Build/Products/Release/$LOCAL_APP_NAME"
    local xcodebuild_args=(
        -project azooKeyMac.xcodeproj
        -scheme azooKeyMac
        -configuration Release
        -derivedDataPath "$build_dir"
        CODE_SIGNING_ALLOWED=NO
        CODE_SIGNING_REQUIRED=NO
        build
    )

    if command -v xcpretty &> /dev/null
    then
        xcodebuild "${xcodebuild_args[@]}" | xcpretty
    else
        echo "xcpretty could not be found. Proceeding without xcpretty."
        xcodebuild "${xcodebuild_args[@]}"
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "DRY RUN: Would execute the following commands:"
        echo "  mkdir -p $LOCAL_APP_DIR"
        echo "  rm -rf $LOCAL_APP_DST"
        echo "  cp -R $app_src $LOCAL_APP_DST"
        echo "  codesign --force --deep --sign - --entitlements ./azooKeyMac/azooKeyMac.entitlements $LOCAL_APP_DST"
        echo "  $LSREGISTER -f -R -trusted $LOCAL_APP_DST"
        echo "  killall TextInputMenuAgent cfprefsd"
        echo "Build completed successfully. Use without --dry-run to actually install."
        return
    fi

    mkdir -p "$LOCAL_APP_DIR"
    rm -rf "$LOCAL_APP_DST"
    cp -R "$app_src" "$LOCAL_APP_DST"
    codesign --force --deep --sign - --entitlements ./azooKeyMac/azooKeyMac.entitlements "$LOCAL_APP_DST"
    "$LSREGISTER" -f -R -trusted "$LOCAL_APP_DST"
    killall TextInputMenuAgent cfprefsd 2>/dev/null || true
}

run_system_install() {
    local xcodebuild_args=(
        -project azooKeyMac.xcodeproj
        -scheme azooKeyMac
        clean archive
        -archivePath build/archive.xcarchive
        -allowProvisioningUpdates
        -destination "generic/platform=macOS"
    )

    if command -v xcpretty &> /dev/null
    then
        xcodebuild "${xcodebuild_args[@]}" | xcpretty
    else
        echo "xcpretty could not be found. Proceeding without xcpretty."
        xcodebuild "${xcodebuild_args[@]}"
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "DRY RUN: Would execute the following commands:"
        echo "  sudo rm -rf /Library/Input\ Methods/azooKeyMac.app"
        echo "  sudo cp -r build/archive.xcarchive/Products/Applications/azooKeyMac.app /Library/Input\ Methods/"
        echo "  pkill azooKeyMac"
        echo "Build completed successfully. Use without --dry-run to actually install."
        return
    fi

    sudo rm -rf /Library/Input\ Methods/azooKeyMac.app
    sudo cp -r build/archive.xcarchive/Products/Applications/azooKeyMac.app /Library/Input\ Methods/
    pkill azooKeyMac
}

if [ "$INSTALL_MODE" = local ]; then
    run_local_install
else
    run_system_install
fi
