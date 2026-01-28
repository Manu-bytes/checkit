#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"

  TEST_FILE="clip_test.txt"
  echo "copiame" >"$TEST_FILE"

  # Directory for fake binaries
  MOCK_BIN_DIR="$BATS_TMPDIR/checkit_mocks"
  mkdir -p "$MOCK_BIN_DIR"

  # Generic script that saves input to a file
  # Note: Uses absolute path for 'cat' to avoid PATH issues inside the mock
  local MOCK_SCRIPT="$MOCK_BIN_DIR/generic_mock"
  cat <<EOF >"$MOCK_SCRIPT"
#!/bin/bash
/bin/cat > "$BATS_TMPDIR/clipboard_content"
exit 0
EOF
  chmod +x "$MOCK_SCRIPT"

  # Create symlinks for all supported tools
  ln -s "$MOCK_SCRIPT" "$MOCK_BIN_DIR/pbcopy"
  ln -s "$MOCK_SCRIPT" "$MOCK_BIN_DIR/wl-copy"
  ln -s "$MOCK_SCRIPT" "$MOCK_BIN_DIR/xclip"
  ln -s "$MOCK_SCRIPT" "$MOCK_BIN_DIR/xsel"

  # Inject mock dir into PATH, but PRESERVE system paths
  # explicitly adding /usr/bin and /bin to ensure core utils are found
  export PATH="$MOCK_BIN_DIR:$PATH"
}

teardown() {
  rm -f "$TEST_FILE"
  rm -rf "$MOCK_BIN_DIR"
  rm -f "$BATS_TMPDIR/clipboard_content"
}

@test "Integration: checkit --copy copies hash to clipboard" {
  # Executing with --copy flag
  run "$CHECKIT_EXEC" "$TEST_FILE" --copy

  assert_success

  # Verify invocation
  if [ ! -f "$BATS_TMPDIR/clipboard_content" ]; then
    # Debugging info
    echo "Debug: Output of checkit:" >&2
    echo "$output" >&2
    fail "Clipboard tool was not invoked (mock file missing). Path used: $PATH"
  fi

  run cat "$BATS_TMPDIR/clipboard_content"
  assert_output --partial "clip_test.txt"
}
