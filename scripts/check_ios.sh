#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

simulator_destination="${DSH_SIMULATOR_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2}"
# Xcode may otherwise select an x86_64 destination on an Apple silicon runner.
# Keep an explicit caller architecture; default to the physical host's architecture.
if [[ ",$simulator_destination," != *,arch=*,* ]]; then
  simulator_arch="$(uname -m)"
  if [[ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" == "1" ]]; then
    simulator_arch=arm64
  fi
  simulator_destination+=",arch=$simulator_arch"
fi

python3 -I scripts/generate_xcode_project.py --check
swift test --package-path Packages/DSHCore
xcodebuild -version
xcodebuild -project DSH.xcodeproj -scheme DSH \
  -destination "$simulator_destination" \
  -derivedDataPath build/DerivedData \
  -resultBundlePath "build/Tests-$(date +%s).xcresult" \
  ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO test
