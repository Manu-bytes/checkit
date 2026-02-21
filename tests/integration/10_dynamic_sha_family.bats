#!/usr/bin/env bats
#
# tests/integration/10_dynamic_sha_family.bats
# Integration Test: Dynamic SHA Family Mapping
#
# Responsibility: Verify that when a 'shasums.txt' context is detected,
# the system correctly dispatches different SHA versions based on hash
# length while strictly ignoring non-SHA algorithms (like MD5).

load '../test_helper'

setup() {
  load_lib "constants.sh"

  # 1. Sandbox Setup
  TEST_DIR="$(mktemp -d "${BATS_TMPDIR}/checkit_sha_family_XXXXXX")"
  DATA_FILE="${TEST_DIR}/data.bin"
  touch "$DATA_FILE"

  # 2. Dummy Hashes
  HASH_SHA256=$(printf 'a%.0s' {1..64})
  HASH_SHA512=$(printf 'b%.0s' {1..128})
  HASH_MD5=$(printf 'c%.0s' {1..32})

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

# --- Tests ---

@test "Dynamic SHA: 'shasums.txt' correctly maps various SHA lengths and skips MD5" {
  # Scenario: A file named 'shasums.txt' containing SHA-256, SHA-512, and an MD5 line.
  local sumfile="${TEST_DIR}/shasums.txt"
  {
    echo "${HASH_SHA256}  ${DATA_FILE}"
    echo "${HASH_SHA512}  ${DATA_FILE}"
    echo "${HASH_MD5}  ${DATA_FILE}"
  } >"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  # The overall execution should be success (it processed what it could)
  assert_success

  # 1. Verify specific SHA versions were used
  assert_output --partial "[OK]"
  assert_output --partial "(sha256)"
  assert_output --partial "(sha512)"

  # 2. Verify MD5 was skipped because it's not part of the SHA family
  assert_output --partial "SKIPPED"
  assert_output --partial "Not a SHA hash"

  # 3. Verify internal binary calls via logs
  run grep "SHA256SUM_CALLED" "$LOG_FILE"
  assert_success

  run grep "SHA512SUM_CALLED" "$LOG_FILE"
  assert_success

  # CRITICAL: MD5SUM should NEVER be called even if the line exists
  run grep "MD5SUM_CALLED" "$LOG_FILE"
  assert_failure
}
