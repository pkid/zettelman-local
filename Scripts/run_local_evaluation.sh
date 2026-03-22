#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17}"
SAMPLE_DIR="$ROOT_DIR/Evaluation/.local-samples"

if [[ ! -d "$SAMPLE_DIR" ]]; then
  echo "Local sample directory not found. Run Scripts/prepare_local_samples.sh first." >&2
  exit 1
fi

ruby "$ROOT_DIR/Scripts/generate_xcodeproj.rb" >/dev/null
xcodebuild test \
  -project "$ROOT_DIR/ZettelmanLocal.xcodeproj" \
  -scheme ZettelmanLocal \
  -destination "$DESTINATION" \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:ZettelmanLocalTests/SampleScanIntegrationTests
