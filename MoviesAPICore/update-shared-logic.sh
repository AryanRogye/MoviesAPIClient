#!/bin/sh

set -eu

package_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repository_dir=$(dirname "$package_dir")
shared_dir="$repository_dir/MoviesShared"
source_framework="$shared_dir/sharedLogic/build/XCFrameworks/release/SharedLogic.xcframework"
destination_dir="$package_dir/Frameworks"

cd "$shared_dir"
./gradlew :sharedLogic:assembleSharedLogicReleaseXCFramework

mkdir -p "$destination_dir"
rm -rf "$destination_dir/SharedLogic.xcframework"
ditto "$source_framework" "$destination_dir/SharedLogic.xcframework"

echo "Updated $destination_dir/SharedLogic.xcframework"
