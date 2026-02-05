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

# function to generate mock binaries (integration)
setup_integration_mocks() {
  local mock_dir="$1"
  local log_file="$2"

  mkdir -p "$mock_dir"

  local tools=("sha1sum" "sha256sum" "sha512sum" "md5sum" "b2sum" "shasum")

  for tool in "${tools[@]}"; do
    cat <<EOF >"$mock_dir/$tool"
#!/bin/bash
# 1. Ignore input (stdin)
cat > /dev/null

BIN_NAME=\$(basename "\$0")

if [[ "\$BIN_NAME" == "shasum" ]]; then
  # CASE: shasum (Perl)
  # Must inspect arguments (e.g., shasum -a 512)

  # Default to SHA1 if no algorithm argument is provided
  ALGO="SHA1"

  if [[ "\$*" =~ -a[[:space:]]*([0-9]+) ]]; then
     BITS="\${BASH_REMATCH[1]}"
     ALGO="SHA\${BITS}"
  fi

  NAME="\$ALGO"

else
  # CASE: sha256sum, md5sum, b2sum
  # sha256sum -> SHA256SUM -> SHA256

  NAME=\$(echo "\$BIN_NAME" | tr '[:lower:]' '[:upper:]' | sed 's/SUM//')

  if [[ "\$NAME" == "SHA" ]]; then NAME="SHA1"; fi
fi

echo "\${NAME}SUM_CALLED" >> "$log_file"
exit 0
EOF
    chmod +x "$mock_dir/$tool"
  done
}
