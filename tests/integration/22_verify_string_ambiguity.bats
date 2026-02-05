#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"

  TEST_FILE="debian.iso"
  touch "$TEST_FILE"

  HASH_40=$(printf 'a%.0s' {1..40})

  MOCK_BIN_DIR="$BATS_TMPDIR/checkit_mocks_ambiguity"
  mkdir -p "$MOCK_BIN_DIR"

  # Mock sha1sum
  cat <<EOF >"$MOCK_BIN_DIR/sha1sum"
#!/bin/bash
exit 1
EOF
  chmod +x "$MOCK_BIN_DIR/sha1sum"

  cp "$MOCK_BIN_DIR/sha1sum" "$MOCK_BIN_DIR/shasum"

  # Mock blake2-160
  cat <<EOF >"$MOCK_BIN_DIR/b2sum"
#!/bin/bash
if [[ "\$*" == *"-l 160"* ]]; then
  exit 0
fi
exit 1
EOF
  chmod +x "$MOCK_BIN_DIR/b2sum"

  export PATH="$MOCK_BIN_DIR:$PATH"
}

teardown() {
  rm -rf "$MOCK_BIN_DIR"
  rm -f "$TEST_FILE"
}

@test "Verify String: Falls back to BLAKE2-160 if SHA-1 fails (Ambiguity Resolution)" {
  run "$CHECKIT_EXEC" "$TEST_FILE" "$HASH_40"

  assert_success
  assert_output --partial "[OK] $TEST_FILE (blake2-160)"
}

@test "Verify String: Respects --algo flag overriding auto-detection" {
  run "$CHECKIT_EXEC" --algo blake2-160 "$TEST_FILE" "$HASH_40"

  assert_success
  assert_output --partial "[OK] $TEST_FILE (blake2-160)"
}
