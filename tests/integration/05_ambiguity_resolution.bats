#!/usr/bin/env bash

load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"

  MOCK_BIN_DIR="$BATS_TMPDIR/checkit_mocks_algo"
  mkdir -p "$MOCK_BIN_DIR"

  EVIDENCE_FILE="$BATS_TMPDIR/called_binary.txt"
  rm -f "$EVIDENCE_FILE"

  # Mock sha512sum to track execution.
  cat <<EOF >"$MOCK_BIN_DIR/sha512sum"
#!/bin/bash
echo "SHA512_CALLED" > "$EVIDENCE_FILE"
exit 0
EOF
  chmod +x "$MOCK_BIN_DIR/sha512sum"

  # Mock b2sum to track execution.
  cat <<EOF >"$MOCK_BIN_DIR/b2sum"
#!/bin/bash
echo "B2SUM_CALLED" > "$EVIDENCE_FILE"
exit 0
EOF
  chmod +x "$MOCK_BIN_DIR/b2sum"

  # Inject mocks into PATH.
  export PATH="$MOCK_BIN_DIR:$PATH"

  # Generate 128-character dummy hash for collision tests.
  DUMMY_HASH=$(printf 'a%.0s' {1..128})
  DATA_FILE="data.txt"
  touch "$DATA_FILE"
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

  # Confirm sha512sum execution.
  run cat "$EVIDENCE_FILE"
  assert_output "SHA512_CALLED"
}

@test "Integration: checkit resolves to BLAKE2 using .b2 extension hint" {
  # Validate resolution via file extension.
  local sumfile="hashes.b2"
  echo "$DUMMY_HASH  $DATA_FILE" >"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  assert_success

  # Confirm b2sum execution based on extension hint.
  run cat "$EVIDENCE_FILE"
  assert_output "B2SUM_CALLED"
}

@test "Integration: checkit resolves to BLAKE2 using BSD tag in content" {
  # Validate resolution via BSD tag detection.
  local sumfile="bsd_hashes.txt"
  echo "BLAKE2 (data.txt) = $DUMMY_HASH" >"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  assert_success

  # Confirm b2sum execution via content parsing.
  run cat "$EVIDENCE_FILE"
  assert_output "B2SUM_CALLED"
}

@test "Integration: checkit resolves to BLAKE2-256 using B2SUMS filename" {
  # Verify mapping for explicit BLAKE2 filenames.
  local sumfile="B2SUMS"
  echo "$DUMMY_HASH  $DATA_FILE" >"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  assert_success

  # Confirm b2sum execution via filename pattern.
  run cat "$EVIDENCE_FILE"
  assert_output "B2SUM_CALLED"
}
