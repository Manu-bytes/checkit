# tests/test_helper.bash

# Detect where this helper file is located
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Load libraries using the detected absolute path
load "$TESTS_DIR/libs/bats-support/load"
load "$TESTS_DIR/libs/bats-assert/load"

# Define project root
PROJECT_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

# export PROJECT_ROOT
export PROJECT_ROOT

# Define the executable to be tested
if [ "${USE_DIST:-}" == "true" ]; then
  export CHECKIT_EXEC="$PROJECT_ROOT/dist/checkit"
else
  export CHECKIT_EXEC="$PROJECT_ROOT/bin/checkit"
fi
