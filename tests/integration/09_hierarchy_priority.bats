#!/usr/bin/env bats
#
# tests/integration/09_hierarchy_priority.bats
# Integration Test: Algorithm Selection Hierarchy and Priority
#
# Responsibility: Validate the decision-making hierarchy:
# 1. Level 1 (Strict): Filename-based context (e.g., SHA256SUMS).
# 2. Level 2 (Medium): Internal metadata headers (Content-Hash).
# 3. Level 3 (Low): Neutral/Mixed mode (heuristic per line).

load '../test_helper'

setup() {
  load_lib "constants.sh"

  # 1. Sandbox Setup
  TEST_DIR="$(mktemp -d "${BATS_TMPDIR}/checkit_hierarchy_XXXXXX")"
  DATA_FILE="${TEST_DIR}/data.bin"
  touch "$DATA_FILE"

  # 2. Dummy Hash Generation
  HASH_SHA256=$(printf 'a%.0s' {1..64})
  HASH_MD5=$(printf 'b%.0s' {1..32})
  HASH_SHA1=$(printf 'c%.0s' {1..40})

  # 3. Setup Mocks
  MOCK_BIN_DIR="${TEST_DIR}/bin"
  LOG_FILE="${TEST_DIR}/calls.log"
  mkdir -p "$MOCK_BIN_DIR"
  setup_integration_mocks "$MOCK_BIN_DIR" "$LOG_FILE"

  # 4. Inject mocks into PATH
  export PATH="$MOCK_BIN_DIR:$PATH"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# --- Hierarchy Level 1: Filename Priority ---

@test "Hierarchy L1: Strict Naming (SHA256SUMS) skips format mismatch (MD5 lines)" {
  # Scenario: A file named SHA256SUMS contains both SHA256 and MD5 lines.
  # Expectation: Only SHA256 should be processed; MD5 should be skipped as format mismatch.

  local sumfile="${TEST_DIR}/SHA256SUMS"
  echo "$HASH_SHA256  $DATA_FILE" >"$sumfile"
  echo "$HASH_MD5  $DATA_FILE" >>"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  assert_success
  assert_output --partial "[OK]"
  assert_output --partial "(sha256)"
  assert_output --partial "SKIPPED" # MD5 line is ignored due to context

  # Verify only SHA256 binary was ever called
  run grep "SHA256SUM_CALLED" "$LOG_FILE"
  assert_success
  run grep "MD5SUM_CALLED" "$LOG_FILE"
  assert_failure
}

# --- Hierarchy Level 2: Metadata Header Priority ---

@test "Hierarchy L2: Internal Metadata (Content-Hash: SHA1) enforces algo on generic filename" {
  # Scenario: Generic filename, but internal GPG-like header specifies SHA1.
  # Expectation: SHA1 lines pass, SHA256 lines are skipped.

  local sumfile="${TEST_DIR}/generic_meta.txt"
  {
    echo "-----BEGIN PGP SIGNED MESSAGE-----"
    echo "Hash: SHA512" # Standard GPG header (should be ignored)
    echo ""
    echo "Content-Hash: SHA1" # Our custom priority header
    echo ""
    echo "$HASH_SHA1  $DATA_FILE"
    echo "$HASH_SHA256  $DATA_FILE"
  } >"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  assert_success
  assert_output --partial "[OK]"
  assert_output --partial "(sha1)"
  assert_output --partial "SKIPPED"

  run grep "SHA1SUM_CALLED" "$LOG_FILE"
  assert_success
  run grep "SHA256SUM_CALLED" "$LOG_FILE"
  assert_failure
}

# --- Hierarchy Level 3: Neutral/Mixed Mode ---

@test "Hierarchy L3: General Compatibility allows mixed modes in neutral files" {
  # Scenario: Filename 'neutral.txt' with no headers.
  # Expectation: All valid lines are processed by guessing the algo per line.

  local sumfile="${TEST_DIR}/neutral.txt"
  echo "$HASH_SHA256  $DATA_FILE" >"$sumfile"
  echo "$HASH_SHA1    $DATA_FILE" >>"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  assert_success
  assert_output --partial "[OK]"
  assert_output --partial "(sha256)"
  assert_output --partial "(sha1)"

  # Verify both binaries were invoked
  run grep "SHA1SUM_CALLED" "$LOG_FILE"
  assert_success
  run grep "SHA256SUM_CALLED" "$LOG_FILE"
  assert_success
}
