#!/usr/bin/env bats
#
# tests/integration/03_create_mode.bats
# Integration Test: Create Mode (Hash Generation)
#
# Responsibility: Validate that the tool correctly calculates hashes for files
# using supported algorithms and output formats (GNU, JSON).

load '../test_helper'

setup() {
  load_lib "constants.sh"

  # Sandbox setup
  TEST_DIR="$(mktemp -d "${BATS_TMPDIR}/checkit_create_XXXXXX")"
  TEST_FILE="${TEST_DIR}/gen_test.txt"
  echo "content_for_hashing" >"$TEST_FILE"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "Integration: checkit generates SHA256 by default (implicit mode)" {
  # 1. Pre-calculate expected hash using system tool
  if ! command -v sha256sum >/dev/null; then skip "sha256sum tool missing"; fi

  local expected_hash
  expected_hash=$(sha256sum "$TEST_FILE" | awk '{print $1}')

  # 2. Execution
  run "$CHECKIT_EXEC" "$TEST_FILE"

  # 3. Validation
  assert_success
  # Verify the hash matches system calculation
  assert_output --partial "$expected_hash"
  # Verify the filename is present
  assert_output --partial "$TEST_FILE"
}

@test "Integration: checkit generates MD5 with --algo flag" {
  if ! command -v md5sum >/dev/null; then skip "md5sum tool missing"; fi

  local expected_hash
  expected_hash=$(md5sum "$TEST_FILE" | awk '{print $1}')

  run "$CHECKIT_EXEC" "$TEST_FILE" --algo md5

  assert_success
  assert_output --partial "$expected_hash"
  assert_output --partial "$TEST_FILE"
}

@test "Integration: checkit generates JSON output correctly" {
  # This verifies the entire pipeline: Args -> Logic -> Formatter -> Output
  run "$CHECKIT_EXEC" "$TEST_FILE" --output json

  assert_success
  # Simple JSON structure check
  assert_output --partial '"algorithm": "sha256"'
  assert_output --partial "\"filename\": \"$TEST_FILE\""
  assert_output --partial '"hash":'
}

@test "Integration: checkit fails on missing file for generation" {
  run "$CHECKIT_EXEC" "${TEST_DIR}/non_existent.txt"

  # Should return Operational Error (2)
  assert_failure "$EX_OPERATIONAL_ERROR"
  assert_output --partial "MISSING"
}
