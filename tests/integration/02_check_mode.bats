#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"

  #1. We create a real data file.
  DATA_FILE="data_test.txt"
  echo "Contenido critico del sistema" >"$DATA_FILE"

  # 2. We generate REAL checksum files using system tools.
  # This ensures that checkit is compatible with real sha256sum/md5sum.
  SUM_SHA256="checksums.sha256"
  sha256sum "$DATA_FILE" >"$SUM_SHA256"

  SUM_MD5="checksums.md5"
  md5sum "$DATA_FILE" >"$SUM_MD5"
}

teardown() {
  rm -f "$DATA_FILE" "$SUM_SHA256" "$SUM_MD5"
}

@test "Integration: checkit -c detects and verifies SHA-256 sumfile" {
  run "$CHECKIT_EXEC" -c "$SUM_SHA256"

  assert_success
  assert_output --partial "Batch verification passed (sha256)"
}

@test "Integration: checkit -c detects and verifies MD5 sumfile" {
  run "$CHECKIT_EXEC" -c "$SUM_MD5"

  assert_success
  assert_output --partial "Batch verification passed (md5)"
}

@test "Integration: checkit -c fails cleanly on checksum mismatch" {
  # We create a corrupted sum file (valid hash length, but incorrect)
  BAD_SUM="bad.sha256"
  # A random SHA256 hash
  echo "0000000000000000000000000000000000000000000000000000000000000000  $DATA_FILE" >"$BAD_SUM"

  run "$CHECKIT_EXEC" -c "$BAD_SUM"

  assert_failure "$EX_INTEGRITY_FAIL"
  assert_output --partial "Batch verification failed"

  rm "$BAD_SUM"
}

@test "Integration: checkit -c fails if sumfile does not exist" {
  run "$CHECKIT_EXEC" -c "ghost_file.txt"

  assert_failure "$EX_OPERATIONAL_ERROR"
}
