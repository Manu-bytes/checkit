#!/usr/bin/env bats
#
# tests/integration/25_check_copy.bats
# Integration Test: Copy Flag in Check Mode
#
# Responsibility: Verify that using --copy (-y) in check mode correctly
# captures the verification report and sends it to the clipboard.

load '../test_helper'

setup() {
  load_lib "constants.sh"

  # 1. Sandbox Setup
  TEST_DIR="$(mktemp -d "${BATS_TMPDIR}/checkit_check_copy_XXXXXX")"

  # 2. Setup Files
  DATA_FILE="${TEST_DIR}/data.txt"
  echo "content" >"$DATA_FILE"

  VALID_HASH="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" # SHA256 of "content\n" (echo default)
  # Recalculate just in case of echo behavior differences
  if command -v sha256sum >/dev/null; then
    VALID_HASH=$(sha256sum "$DATA_FILE" | awk '{print $1}')
  fi

  SUMFILE="${TEST_DIR}/checksums.txt"
  echo "$VALID_HASH  $DATA_FILE" >"$SUMFILE"

  # 3. Setup Mocks
  MOCK_BIN_DIR="${TEST_DIR}/bin"
  mkdir -p "$MOCK_BIN_DIR"

  # Clipboard Mock: Saves input to a file
  CLIP_OUT="${TEST_DIR}/clipboard_content.txt"
  cat <<EOF >"$MOCK_BIN_DIR/pbcopy"
#!/bin/bash
cat > "$CLIP_OUT"
EOF
  chmod +x "$MOCK_BIN_DIR/pbcopy"

  # Mock Hasher (Pass-through for verify)
  cat <<EOF >"$MOCK_BIN_DIR/sha256sum"
#!/bin/bash
if [[ "\$*" == *"-c"* ]]; then exit 0; fi
echo "$VALID_HASH  \$1"
EOF
  chmod +x "$MOCK_BIN_DIR/sha256sum"

  export PATH="$MOCK_BIN_DIR:$PATH"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "Check+Copy: -c -y pipes verification report to clipboard" {
  # Execution: Check mode WITH copy flag
  run "$CHECKIT_EXEC" -c "$SUMFILE" --copy

  assert_success

  # 1. Verify Standard Output (User still sees it)
  assert_output --partial "[OK]"
  assert_output --partial "data.txt"

  # 2. Verify Clipboard Content
  if [ ! -f "$CLIP_OUT" ]; then
    fail "Clipboard mock was not invoked (output file missing)"
  fi

  # Read clipboard content
  local clip_content
  clip_content=$(cat "$CLIP_OUT")

  # The clipboard should contain the SAME report as stdout
  # We check for key fragments
  [[ "$clip_content" == *"[OK]"* ]] || fail "Clipboard missing [OK] status"
  [[ "$clip_content" == *"data.txt"* ]] || fail "Clipboard missing filename"
}
