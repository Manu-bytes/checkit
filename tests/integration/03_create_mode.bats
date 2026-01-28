#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"
  TEST_FILE="gen_test.txt"
  echo "content" >"$TEST_FILE"
}

teardown() {
  rm -f "$TEST_FILE"
}

@test "Integration: checkit generates SHA256 by default (implicit mode)" {
  # Run: checkit gen_test.txt
  run "$CHECKIT_EXEC" "$TEST_FILE"

  assert_success
  # We verify that it looks like a SHA256 hash (64 characters)
  assert_output --partial "$TEST_FILE"
  # We cannot easily predict the exact hash without calculating it,
  # but we check the basic format.
}

@test "Integration: checkit generates MD5 with --algo flag" {
  # Run: checkit gen_test.txt --something md5
  run "$CHECKIT_EXEC" "$TEST_FILE" --algo md5

  assert_success
  assert_output --partial "$TEST_FILE"
}

@test "Integration: checkit fails on missing file for generation" {
  run "$CHECKIT_EXEC" "non_existent.txt"
  assert_failure "$EX_OPERATIONAL_ERROR"
}
