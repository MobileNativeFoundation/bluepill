#!/bin/bash

set -euo pipefail

OUT_FILE=$1
REPO_ROOT=$(git rev-parse --show-toplevel)
VERSION=$(git describe --always --tags)
test -z "$VERSION" && VERSION=$(cat "$REPO_ROOT/VERSION")
echo "#define BP_VERSION \"$VERSION\"" > "$OUT_FILE"
XCODE_VERSION=$(xcodebuild -version | awk 'BEGIN {OFS="";} /Xcode/ {version=$2} /Build version/ {build=$3} END {print version, " (", build, ")";}')
echo "#define XCODE_VERSION \"$XCODE_VERSION\"" >> "$OUT_FILE"
