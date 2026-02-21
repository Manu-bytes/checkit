#!/usr/bin/env bats
#
# tests/integration/05_ambiguity_resolution.bats
# Integration Test: Ambiguity Resolution
#
# Responsibility: Verify that the system correctly chooses between colliding
# algorithms (e.g., SHA-512 vs BLAKE2b, both 128 chars) based on context hints
# (filename extensions, headers, BSD tags).

load '../test_helper'

setup() {
  load_lib "constants.sh"

  # 1. Sandbox Setup
  TEST_DIR="$(mktemp -d "${BATS_TMPDIR}/checkit_ambiguity_XXXXXX")"

  # Data file to be "hashed"
  DATA_FILE="${TEST_DIR}/data.txt"
  touch "$DATA_FILE"

  # 2. Generate a 128-character dummy hash
  # This length causes a collision between SHA-512 and BLAKE2b
  DUMMY_HASH=$(printf 'a%.0s' {1..128})

  # 3. Setup Mocks
  # We use the helper to generate fake binaries that log their execution
  MOCK_BIN_DIR="${TEST_DIR}/mocks"
  LOG_FILE="${TEST_DIR}/calls.log"

  # Generate mocks (sha512sum, b2sum, etc.)
  setup_integration_mocks "$MOCK_BIN_DIR" "$LOG_FILE"

  # 4. Inject mocks into PATH
  export PATH="$MOCK_BIN_DIR:$PATH"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "Integration: checkit defaults to SHA-512 for 128-char hashes (No context)" {
  # Scenario: Standard .txt extension, no headers.
  # Expectation: Default to SHA family.

  local sumfile="${TEST_DIR}/hashes.txt"
  echo "$DUMMY_HASH  $DATA_FILE" >"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  assert_success

  # Verification: Check logs to see WHICH binary was called
  run cat "$LOG_FILE"
  assert_output --partial "SHA512SUM_CALLED"
}

@test "Integration: checkit resolves to BLAKE2 using .b2 extension hint" {
  # Scenario: Filename ends in .b2
  # Expectation: Context overrides default length check.

  local sumfile="${TEST_DIR}/hashes.b2"
  echo "$DUMMY_HASH  $DATA_FILE" >"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  assert_success

  run cat "$LOG_FILE"
  assert_output --partial "B2SUM_CALLED"
}

@test "Integration: checkit resolves to BLAKE2 using BSD tag in content" {
  # Scenario: File content has 'BLAKE2 (...) =' tag
  # Expectation: Tag overrides everything.

  local sumfile="${TEST_DIR}/bsd_hashes.txt"
  echo "BLAKE2 ($DATA_FILE) = $DUMMY_HASH" >"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  assert_success

  run cat "$LOG_FILE"
  assert_output --partial "B2SUM_CALLED"
}

@test "Integration: checkit resolves to BLAKE2-256 using B2SUMS filename" {
  # Scenario: Filename is exactly 'B2SUMS'
  # Expectation: Treated as Blake family context.

  local sumfile="${TEST_DIR}/B2SUMS"
  echo "$DUMMY_HASH  $DATA_FILE" >"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  assert_success

  run cat "$LOG_FILE"
  assert_output --partial "B2SUM_CALLED"
}
