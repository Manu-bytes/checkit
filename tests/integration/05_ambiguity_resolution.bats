#!/usr/bin/env bash

load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"

  DATA_FILE="data.txt"
  touch "$DATA_FILE"

  # Generate 128-character dummy hash for collision tests.
  DUMMY_HASH=$(printf 'a%.0s' {1..128})

  MOCK_BIN_DIR="$BATS_TMPDIR/checkit_mocks_algo"
  LOG_FILE="$BATS_TMPDIR/calls.log"
  rm -f "$LOG_FILE"

  setup_integration_mocks "$MOCK_BIN_DIR" "$LOG_FILE"

  # Inject mocks into PATH.
  export PATH="$MOCK_BIN_DIR:$PATH"
}

teardown() {
  rm -rf "$MOCK_BIN_DIR"
  rm -f "$DATA_FILE"
  rm -f "hashes.txt" "hashes.b2" "bsd_hashes.txt" "B2SUMS"
}

@test "Integration: checkit defaults to SHA-512 for 128-char hashes" {
  # Verify default resolution without hints.
  local sumfile="hashes.txt"
  echo "$DUMMY_HASH  $DATA_FILE" >"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  assert_success

  run cat "$LOG_FILE"
  assert_output "SHA512SUM_CALLED"
}

@test "Integration: checkit resolves to BLAKE2 using .b2 extension hint" {
  # Validate resolution via file extension.
  local sumfile="hashes.b2"
  echo "$DUMMY_HASH  $DATA_FILE" >"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  assert_success

  run cat "$LOG_FILE"
  assert_output "B2SUM_CALLED"
}

@test "Integration: checkit resolves to BLAKE2 using BSD tag in content" {
  # Validate resolution via BSD tag detection.
  local sumfile="bsd_hashes.txt"
  echo "BLAKE2 (data.txt) = $DUMMY_HASH" >"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  assert_success

  run cat "$LOG_FILE"
  assert_output "B2SUM_CALLED"
}

@test "Integration: checkit resolves to BLAKE2-256 using B2SUMS filename" {
  # Verify mapping for explicit BLAKE2 filenames.
  local sumfile="B2SUMS"
  echo "$DUMMY_HASH  $DATA_FILE" >"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  assert_success

  run cat "$LOG_FILE"
  assert_output "B2SUM_CALLED"
}
