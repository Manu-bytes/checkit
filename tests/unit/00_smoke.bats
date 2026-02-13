#!/usr/bin/env bats
#
# tests/unit/00_smoke.bats
# Smoke Tests: Validates basic environment integrity.
#
# Responsibility: Ensure the test harness loads and the executable is accessible.

load '../test_helper'

@test "Smoke: The test environment loads correctly" {
  run true
  assert_success
}

@test "Smoke: The checkit executable exists and is executable" {
  assert [ -x "$CHECKIT_EXEC" ]
}

@test "Smoke: checkit rejects execution without arguments (Exit Code 2)" {
  run "$CHECKIT_EXEC"

  # Expect EX_OPERATIONAL_ERROR (2) defined in constants.sh
  assert_failure 2

  # Ensure some help/usage text is printed
  assert_output --partial "Usage"
}

@test "Smoke: checkit --version returns success" {
  run "$CHECKIT_EXEC" --version
  assert_success
  assert_output --partial "checkit v"
}
