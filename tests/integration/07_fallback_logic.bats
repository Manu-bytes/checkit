#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"

  # Create dummy file and sumfile
  DATA_FILE="data.iso"
  touch "$DATA_FILE"

  # A 64-char hash. checkit will guess SHA-256 first.
  # Since we mocked sha256sum to fail and b2sum to pass,
  # success proves the fallback logic executed.
  HASH_64=$(printf 'a%.0s' {1..64})
  NEUTRAL_SUMFILE="neutral_hashes.txt"
  echo "$HASH_64  $DATA_FILE" >"$NEUTRAL_SUMFILE"

  # Mock binaries to simulate collision behavior
  MOCK_BIN_DIR="$BATS_TMPDIR/checkit_mocks_fallback"
  LOG_FILE="$BATS_TMPDIR/fallback_calls.log"
  rm -f "$LOG_FILE"

  setup_integration_mocks "$MOCK_BIN_DIR" "$LOG_FILE"

  # 1. Mock sha256sum: ALWAYS FAILS
  cat <<EOF >"$MOCK_BIN_DIR/sha256sum"
#!/bin/bash
cat > /dev/null
echo "SHA256SUM_CALLED" >> "$LOG_FILE"
exit 1
EOF
  chmod +x "$MOCK_BIN_DIR/sha256sum"
  cp "$MOCK_BIN_DIR/sha256sum" "$MOCK_BIN_DIR/shasum"

  export PATH="$MOCK_BIN_DIR:$PATH"
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

  # We verify the flow in the log:
  run grep "SHA256SUM_CALLED" "$LOG_FILE"
  assert_success
  run grep "B2SUM_CALLED" "$LOG_FILE"
  assert_success
}
