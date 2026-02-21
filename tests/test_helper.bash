# tests/test_helper.bash

# 1. Path Resolution
# ----------------------------------------------------------------------
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
export PROJECT_ROOT

# 2. BATS Library Loading
# ----------------------------------------------------------------------
# Ensure submodules are initialized or paths are correct
if [[ -f "$TESTS_DIR/libs/bats-support/load.bash" ]]; then
  load "$TESTS_DIR/libs/bats-support/load"
  load "$TESTS_DIR/libs/bats-assert/load"
fi

# 3. Execution Definitions
# ----------------------------------------------------------------------
# For Integration Tests: Define the binary to execute
if [ "${USE_DIST:-}" == "true" ]; then
  export CHECKIT_EXEC="$PROJECT_ROOT/dist/checkit"
else
  export CHECKIT_EXEC="$PROJECT_ROOT/bin/checkit"
fi

# 4. Helper Functions for Unit Tests
# ----------------------------------------------------------------------
# Public: Sources specific project libraries for unit testing.
# Prevents redefining readonly constants if loaded multiple times.
#
# $1 - Library path relative to lib/ (e.g., "core/parser.sh")
load_lib() {
  local lib_path="$PROJECT_ROOT/lib/$1"
  if [[ -f "$lib_path" ]]; then
    # shellcheck source=/dev/null
    source "$lib_path"
  else
    echo "Error: Library not found: $lib_path" >&2
    return 1
  fi
}

# 5. Helper Functions for Integration Tests
# ----------------------------------------------------------------------

# Public: Generates mock binaries for hash algorithms.
# These mocks simulate successful execution and return a dummy hash
# to satisfy the adapter's output parsing expectations.
#
# $1 - mock_dir - Directory to place the mocks (usually $BATS_TMPDIR)
# $2 - log_file - File to log calls for assertion
setup_integration_mocks() {
  local mock_dir="$1"
  local log_file="$2"

  mkdir -p "$mock_dir"

  local tools=("sha1sum" "sha256sum" "sha512sum" "md5sum" "b2sum" "shasum")

  for tool in "${tools[@]}"; do
    # Note: Variables inside EOF are escaped (\$) to prevent expansion during generation,
    # except for $log_file which we want expanded now.
    cat <<EOF >"$mock_dir/$tool"
#!/bin/bash

# 1. Log the call
BIN_NAME=\$(basename "\$0")

if [[ "\$BIN_NAME" == "shasum" ]]; then
  # Parsing logic for perl script simulation
  ALGO="SHA1"
  if [[ "\$*" =~ -a[[:space:]]*([0-9]+) ]]; then
     BITS="\${BASH_REMATCH[1]}"
     ALGO="SHA\${BITS}"
  fi
  NAME="\$ALGO"
else
  # Parsing logic for coreutils simulation
  NAME=\$(echo "\$BIN_NAME" | tr '[:lower:]' '[:upper:]' | sed 's/SUM//')
  if [[ "\$NAME" == "SHA" ]]; then NAME="SHA1"; fi
fi

echo "\${NAME}SUM_CALLED" >> "$log_file"

# 2. Simulate Output (CRITICAL FIX)
# The adapter expects "HASH  FILENAME".
# We handle both piped input (verify) and file input (calculate).

# Detect if input is a file argument (last argument usually)
LAST_ARG="\${@: -1}"

if [[ -f "\$LAST_ARG" ]]; then
  # Calculate Mode: Output fake hash + filename
  echo "ba5eba11deadbeef0000000000000000  \$LAST_ARG"
else
  # Verify Mode: Read stdin to prevent broken pipe, return success
  cat > /dev/null
fi

exit 0
EOF
    chmod +x "$mock_dir/$tool"
  done
}
