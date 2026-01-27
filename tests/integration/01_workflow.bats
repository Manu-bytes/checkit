#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"

  # temporary file
  TEST_FILE="integration_test.txt"
  echo "secret content" >"$TEST_FILE"
}

# clean temporary file
teardown() {
  rm -f "$TEST_FILE"
}

@test "Integration: checkit validates a correct SHA256 hash" {
  # obtaining file hash
  local valid_hash
  valid_hash=$(sha256sum "$TEST_FILE" | awk '{print $1}')

  # executing the binary
  run "$CHECKIT_EXEC" "$TEST_FILE" "$valid_hash"

  assert_success
  assert_output --partial "OK"
}

@test "Integration: checkit rejects an incorrect hash" {
  # fake hash of correct length (64 characters)
  local bad_hash="0000000000000000000000000000000000000000000000000000000000000000"

  run "$CHECKIT_EXEC" "$TEST_FILE" "$bad_hash"

  assert_failure "$EX_INTEGRITY_FAIL"
  assert_output --partial "FAILED"
}
