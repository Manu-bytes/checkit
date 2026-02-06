#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"

  DATA_FILE="data.iso"
  touch "$DATA_FILE"

  HASH_64=$(printf 'a%.0s' {1..64})

  MOCK_BIN_DIR="$BATS_TMPDIR/checkit_mocks_strict"
  LOG_FILE="$BATS_TMPDIR/strict_calls.log"
  rm -f "$LOG_FILE"

  setup_integration_mocks "$MOCK_BIN_DIR" "$LOG_FILE"
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
  rm -f "$DATA_FILE" "shasums.txt" "neutral.txt"
}

@test "Integration: Neutral file (checksums.txt) ALLOWS fallback to Blake2" {
  local sumfile="neutral.txt"
  echo "$HASH_64  $DATA_FILE" >"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  assert_success
  assert_output --partial "[OK] $DATA_FILE (blake2-256)"

  run grep "SHA256SUM_CALLED" "$LOG_FILE"
  assert_success
  run grep "B2SUM_CALLED" "$LOG_FILE"
  assert_success
}

@test "Integration: Explicit file (shasums.txt) FORBIDS fallback to Blake2" {
  local sumfile="shasums.txt"
  echo "$HASH_64  $DATA_FILE" >"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  assert_failure "$EX_INTEGRITY_FAIL"
  assert_output --partial "[FAILED] $DATA_FILE (sha256)"

  refute_output --partial "blake2"

  run grep "SHA256SUM_CALLED" "$LOG_FILE"
  assert_success
  run grep "B2SUM_CALLED" "$LOG_FILE"
  assert_failure
}
