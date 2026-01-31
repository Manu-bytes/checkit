#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"

  DATA_FILE="data.bin"
  touch "$DATA_FILE"

  HASH_SHA256=$(printf 'a%.0s' {1..64})
  HASH_SHA512=$(printf 'b%.0s' {1..128})
  HASH_MD5=$(printf 'c%.0s' {1..32})

  MOCK_BIN_DIR="$BATS_TMPDIR/checkit_mocks_sha_family"
  mkdir -p "$MOCK_BIN_DIR"
  export PATH="$MOCK_BIN_DIR:$PATH"

  LOG_FILE="$BATS_TMPDIR/calls.log"
  rm -f "$LOG_FILE"

  # Mock SHA256 (Success)
  echo "#!/bin/bash" >"$MOCK_BIN_DIR/sha256sum"
  echo "echo 'sha256sum called' >> $LOG_FILE; exit 0" >>"$MOCK_BIN_DIR/sha256sum"
  chmod +x "$MOCK_BIN_DIR/sha256sum"

  # Mock SHA512 (Success)
  echo "#!/bin/bash" >"$MOCK_BIN_DIR/sha512sum"
  echo "echo 'sha512sum called' >> $LOG_FILE; exit 0" >>"$MOCK_BIN_DIR/sha512sum"
  chmod +x "$MOCK_BIN_DIR/sha512sum"

  # Mock MD5 (Should NOT be called)
  echo "#!/bin/bash" >"$MOCK_BIN_DIR/md5sum"
  echo "echo 'md5sum called' >> $LOG_FILE; exit 0" >>"$MOCK_BIN_DIR/md5sum"
  chmod +x "$MOCK_BIN_DIR/md5sum"
}

teardown() {
  rm -rf "$MOCK_BIN_DIR" "$LOG_FILE" "shasums.txt" "$DATA_FILE"
}

@test "Dynamic SHA: 'shasums.txt' correctly maps various SHA lengths" {
  local sumfile="shasums.txt"
  echo "$HASH_SHA256  $DATA_FILE" >"$sumfile"
  echo "$HASH_SHA512  $DATA_FILE" >>"$sumfile"

  # MD5 Included: Should be skipped because strict SHA mode excludes MD5
  echo "$HASH_MD5  $DATA_FILE" >>"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  assert_success

  # Verify specific SHA versions were used based on length
  assert_output --partial "[OK] $DATA_FILE (sha256)"
  assert_output --partial "[OK] $DATA_FILE (sha512)"

  assert_output --partial "[SKIPPED] $DATA_FILE (Not a SHA hash)"

  run grep "sha256sum called" "$LOG_FILE"
  assert_success
  run grep "sha512sum called" "$LOG_FILE"
  assert_success

  run grep "md5sum called" "$LOG_FILE"
  assert_failure
}
