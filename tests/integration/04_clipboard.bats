#!/usr/bin/env bats
#
# tests/integration/04_clipboard.bats
# Integration Test: Clipboard Functionality
#
# Responsibility: Validate that the --copy flag correctly pipes the output
# to the system clipboard (simulated via mocks in PATH).

load '../test_helper'

setup() {
  load_lib "constants.sh"

  # 1. Create a secure sandbox
  TEST_DIR="$(mktemp -d "${BATS_TMPDIR}/checkit_clipboard_XXXXXX")"
  TEST_FILE="${TEST_DIR}/clip_test.txt"
  echo "copy me" >"$TEST_FILE"

  # Output file where the mock will write the "copied" content
  CLIPBOARD_OUT="${TEST_DIR}/clipboard_content"

  # 2. Setup Mock Binaries Directory
  MOCK_BIN_DIR="${TEST_DIR}/bin"
  mkdir -p "$MOCK_BIN_DIR"

  # 3. Create a generic mock script
  # This script reads STDIN (what checkit pipes to it) and saves it to a file.
  local MOCK_SCRIPT="${MOCK_BIN_DIR}/generic_mock"

  cat <<EOF >"$MOCK_SCRIPT"
#!/bin/bash
# Capture stdin to the output file
cat > "$CLIPBOARD_OUT"
exit 0
EOF
  chmod +x "$MOCK_SCRIPT"

  # 4. Alias ALL supported clipboard tools to this mock
  # This ensures that no matter what OS run the test, checkit finds our mock first.
  ln -s "$MOCK_SCRIPT" "$MOCK_BIN_DIR/pbcopy"
  ln -s "$MOCK_SCRIPT" "$MOCK_BIN_DIR/wl-copy"
  ln -s "$MOCK_SCRIPT" "$MOCK_BIN_DIR/xclip"
  ln -s "$MOCK_SCRIPT" "$MOCK_BIN_DIR/xsel"

  # 5. Inject Mock Dir into PATH (Prepend to take precedence)
  export PATH="$MOCK_BIN_DIR:$PATH"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "Integration: checkit --copy copies hash + filename to clipboard" {
  # 1. Execution
  run "$CHECKIT_EXEC" "$TEST_FILE" --copy

  assert_success

  # 2. Verify invocation
  if [ ! -f "$CLIPBOARD_OUT" ]; then
    fail "Clipboard tool was not invoked (output file missing). PATH used: $PATH"
  fi

  # 3. Verify content
  # The clipboard should contain the Hash AND the Filename (default format)
  run cat "$CLIPBOARD_OUT"
  assert_output --partial "clip_test.txt"

  # Check for a hash-like string (SHA256 length is 64)
  # We assume a standard hash is generated.
  local content
  content=$(cat "$CLIPBOARD_OUT")
  if [[ ! "$content" =~ [a-f0-9]{32,} ]]; then
    fail "Clipboard content does not look like a hash: $content"
  fi
}

@test "Integration: checkit --copy works with --format json" {
  # 1. Execution with JSON format
  run "$CHECKIT_EXEC" "$TEST_FILE" --format json --copy

  assert_success

  # 2. Verify content
  run cat "$CLIPBOARD_OUT"

  # Should be valid JSON
  assert_output --partial '"algorithm":'
  assert_output --partial '"filename":'
}
