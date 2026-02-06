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
  LOG_FILE="$BATS_TMPDIR/calls.log"
  rm -f "$LOG_FILE"

  setup_integration_mocks "$MOCK_BIN_DIR" "$LOG_FILE"
  export PATH="$MOCK_BIN_DIR:$PATH"
}

teardown() {
  rm -rf "$MOCK_BIN_DIR" "$LOG_FILE" "shasums.txt" "$DATA_FILE"
}

@test "Dynamic SHA: 'shasums.txt' correctly maps various SHA lengths" {
  local sumfile="shasums.txt"
  {
    echo "${HASH_SHA256}  ${DATA_FILE}"
    echo "${HASH_SHA512}  ${DATA_FILE}"
    echo "${HASH_MD5}  ${DATA_FILE}"
  } >>"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"
  assert_success

  # Verify specific SHA versions were used based on length
  assert_output --partial "[OK] $DATA_FILE (sha256)"
  assert_output --partial "[OK] $DATA_FILE (sha512)"
  assert_output --partial "[SKIPPED] $DATA_FILE (Not a SHA hash)"

  run grep "SHA256SUM_CALLED" "$LOG_FILE"
  assert_success
  run grep "SHA512SUM_CALLED" "$LOG_FILE"
  assert_success
  run grep "MD5SUM_CALLED" "$LOG_FILE"
  assert_failure
}
