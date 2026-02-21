#!/usr/bin/env bats
#
# tests/integration/01_workflow.bats
# Integration Test: Real Workflow
#
# Responsibility: Validate the end-to-end execution of the binary using
# real system tools (no mocks). Acts as a smoke test for the installed environment.

load '../test_helper'

setup() {
  # Load constants to access Exit Codes (EX_*)
  load_lib "constants.sh"

  # Create a temporary file in BATS secure temp dir
  TEST_FILE="${BATS_TMPDIR}/integration_workflow_$$"
  echo "secret content" >"$TEST_FILE"
}

teardown() {
  rm -f "$TEST_FILE"
}

@test "Integration: checkit validates a correct SHA256 hash" {
  # 1. Dependency Check
  # Since this is a "Real World" test, we need the system tool.
  if ! command -v sha256sum >/dev/null; then
    skip "sha256sum binary not found in system"
  fi

  # 2. Setup: Calculate real hash
  local valid_hash
  valid_hash=$(sha256sum "$TEST_FILE" | awk '{print $1}')

  # 3. Execution: Run the compiled/source binary
  run "$CHECKIT_EXEC" "$TEST_FILE" "$valid_hash"

  # 4. Assertions
  assert_success
  assert_output --partial "OK"
}

@test "Integration: checkit rejects an incorrect hash" {
  # Fake hash of correct length (64 characters = SHA256)
  local bad_hash="0000000000000000000000000000000000000000000000000000000000000000"

  run "$CHECKIT_EXEC" "$TEST_FILE" "$bad_hash"

  # Expect failure code 1 (EX_INTEGRITY_FAIL)
  assert_failure "$EX_INTEGRITY_FAIL"
  assert_output --partial "FAILED"
}
