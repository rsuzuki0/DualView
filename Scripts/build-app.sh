#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Packaging/Info.plist)
build_root=${DUALVIEW_BUILD_ROOT:-"$project_dir/.build/release-universal"}
arm_scratch="$build_root/arm64"
intel_scratch="$build_root/x86_64"
dist_dir="$project_dir/dist"
temporary_dir=$(mktemp -d "${TMPDIR:-/tmp}/dualview-release.XXXXXX")
temporary_app="$temporary_dir/DualView.app"

cleanup() {
    if test -d "$temporary_dir"; then
        rm -rf -- "$temporary_dir"
    fi
}
trap cleanup EXIT HUP INT TERM

swift build \
    --disable-sandbox \
    -c release \
    --product dualview \
    --triple arm64-apple-macosx11.0 \
    --scratch-path "$arm_scratch"
swift build \
    --disable-sandbox \
    -c release \
    --product dualview \
    --triple x86_64-apple-macosx10.15 \
    --scratch-path "$intel_scratch"

arm_binary="$arm_scratch/arm64-apple-macosx/release/dualview"
intel_binary="$intel_scratch/x86_64-apple-macosx/release/dualview"

contents_dir="$temporary_app/Contents"
macos_dir="$contents_dir/MacOS"
resources_dir="$contents_dir/Resources"

mkdir -p "$macos_dir" "$resources_dir"
lipo -create "$arm_binary" "$intel_binary" -output "$macos_dir/dualview"
cp "$project_dir/Packaging/Info.plist" "$contents_dir/Info.plist"
cp "$project_dir/Assets/DualView.icns" "$resources_dir/DualView.icns"
cp "$project_dir/LICENSE" "$resources_dir/LICENSE.txt"
codesign --force --deep --sign - "$temporary_app"
codesign --verify --deep --strict "$temporary_app"

built_version=$("$macos_dir/dualview" --version)
if test "$built_version" != "DualView $version"; then
    echo "Version mismatch: Info.plist says $version; executable says $built_version" >&2
    exit 1
fi

mkdir -p "$dist_dir"
app_dir="$dist_dir/DualView.app"
if test -e "$app_dir"; then
    mv "$app_dir" "$temporary_dir/previous-DualView.app"
fi
mv "$temporary_app" "$app_dir"

archive="$dist_dir/DualView-$version-universal.zip"
if test -e "$archive"; then
    mv "$archive" "$temporary_dir/previous-release.zip"
fi
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$archive"
(cd "$dist_dir" && shasum -a 256 "$(basename "$archive")" > SHA256SUMS)

echo "Built $app_dir"
echo "Release archive: $archive"
echo "Checksums: $dist_dir/SHA256SUMS"
