#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"

  MOCK_BIN_DIR="$BATS_TMPDIR/checkit_mocks_strict"
  mkdir -p "$MOCK_BIN_DIR"
  export PATH="$MOCK_BIN_DIR:$PATH"

  cat <<EOF >"$MOCK_BIN_DIR/sha256sum"
#!/bin/bash
exit 1
EOF
  chmod +x "$MOCK_BIN_DIR/sha256sum"

  cat <<EOF >"$MOCK_BIN_DIR/b2sum"
#!/bin/bash
exit 0
EOF
  chmod +x "$MOCK_BIN_DIR/b2sum"

  DATA_FILE="data.iso"
  touch "$DATA_FILE"
  HASH_64=$(printf 'a%.0s' {1..64})
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
}

@test "Integration: Explicit file (shasums.txt) FORBIDS fallback to Blake2" {
  local sumfile="shasums.txt"
  echo "$HASH_64  $DATA_FILE" >"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  assert_failure "$EX_INTEGRITY_FAIL"
  assert_output --partial "[FAILED] $DATA_FILE (sha256)"

  refute_output --partial "blake2"
}
