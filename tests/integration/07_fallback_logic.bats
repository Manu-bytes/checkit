#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"

  # Mock binaries to simulate collision behavior
  MOCK_BIN_DIR="$BATS_TMPDIR/checkit_mocks_fallback"
  mkdir -p "$MOCK_BIN_DIR"
  export PATH="$MOCK_BIN_DIR:$PATH"

  # 1. Mock sha256sum: ALWAYS FAILS
  # This simulates attempting SHA256 on a BLAKE2 hash.
  cat <<EOF >"$MOCK_BIN_DIR/sha256sum"
#!/bin/bash
exit 1
EOF
  chmod +x "$MOCK_BIN_DIR/sha256sum"

  # 2. Mock b2sum: ALWAYS SUCCEEDS
  # This simulates the fallback succeeding.
  cat <<EOF >"$MOCK_BIN_DIR/b2sum"
#!/bin/bash
exit 0
EOF
  chmod +x "$MOCK_BIN_DIR/b2sum"

  # Create dummy file and sumfile
  DATA_FILE="data.iso"
  touch "$DATA_FILE"

  # A 64-char hash. checkit will guess SHA-256 first.
  # Since we mocked sha256sum to fail and b2sum to pass,
  # success proves the fallback logic executed.
  HASH_64=$(printf 'a%.0s' {1..64})
  NEUTRAL_SUMFILE="neutral_hashes.txt"
  echo "$HASH_64  $DATA_FILE" >"$NEUTRAL_SUMFILE"
}

teardown() {
  rm -rf "$MOCK_BIN_DIR"
  rm -f "$DATA_FILE" "$NEUTRAL_SUMFILE"
}

@test "Integration: checkit falls back to BLAKE2-256 if SHA-256 verification fails" {
  run "$CHECKIT_EXEC" -c "$NEUTRAL_SUMFILE"

  assert_success

  # It should report OK using the fallback algorithm
  assert_output --partial "[OK] $DATA_FILE (blake2-256)"

  # It should NOT report failure for sha256
  refute_output --partial "[FAILED]"
}
