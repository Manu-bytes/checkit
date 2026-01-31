#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"

  DATA_FILE="data.bin"
  touch "$DATA_FILE"

  HASH_SHA256=$(printf 'a%.0s' {1..64})
  HASH_MD5=$(printf 'b%.0s' {1..32})
  HASH_SHA1=$(printf 'c%.0s' {1..40})

  MOCK_BIN_DIR="$BATS_TMPDIR/checkit_mocks_hierarchy"
  mkdir -p "$MOCK_BIN_DIR"
  export PATH="$MOCK_BIN_DIR:$PATH"

  LOG_FILE="$BATS_TMPDIR/calls.log"
  rm -f "$LOG_FILE"

  echo "#!/bin/bash" >"$MOCK_BIN_DIR/sha256sum"
  echo "echo 'sha256sum called' >> $LOG_FILE; exit 0" >>"$MOCK_BIN_DIR/sha256sum"
  chmod +x "$MOCK_BIN_DIR/sha256sum"

  echo "#!/bin/bash" >"$MOCK_BIN_DIR/sha1sum"
  echo "echo 'sha1sum called' >> $LOG_FILE; exit 0" >>"$MOCK_BIN_DIR/sha1sum"
  chmod +x "$MOCK_BIN_DIR/sha1sum"
}

teardown() {
  rm -rf "$MOCK_BIN_DIR" "$LOG_FILE" "SHA256SUMS" "generic_meta.txt" "neutral.txt" "$DATA_FILE"
}

@test "Hierarchy L1: Strict Naming (SHA256SUMS) skips format mismatch (MD5 lines)" {
  local sumfile="SHA256SUMS"
  echo "$HASH_SHA256  $DATA_FILE" >"$sumfile"
  echo "$HASH_MD5  $DATA_FILE" >>"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  assert_success

  assert_output --partial "[OK] $DATA_FILE (sha256)"

  assert_output --partial "[SKIPPED]"

  run grep "sha256sum called" "$LOG_FILE"
  assert_success
}

@test "Hierarchy L2: Internal Metadata (Hash: SHA1) enforces algo on generic filename" {
  local sumfile="generic_meta.txt"
  echo "-----BEGIN PGP SIGNED MESSAGE-----" >"$sumfile"
  echo "Hash: SHA1" >>"$sumfile"
  echo "" >>"$sumfile"
  echo "$HASH_SHA1  $DATA_FILE" >>"$sumfile"
  echo "$HASH_SHA256  $DATA_FILE" >>"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  assert_success
  assert_output --partial "[OK] $DATA_FILE (sha1)"
  assert_output --partial "[SKIPPED]"

  run grep "sha1sum called" "$LOG_FILE"
  assert_success
  run grep "sha256sum called" "$LOG_FILE"
  assert_failure
}

@test "Hierarchy L3: General Compatibility allows mixed modes" {
  local sumfile="neutral.txt"
  echo "$HASH_SHA256  $DATA_FILE" >"$sumfile"
  echo "$HASH_SHA1    $DATA_FILE" >>"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  assert_success
  assert_output --partial "[OK] $DATA_FILE (sha256)"
  assert_output --partial "[OK] $DATA_FILE (sha1)"
}
