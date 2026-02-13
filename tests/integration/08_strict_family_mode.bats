#!/usr/bin/env bats
#
# tests/integration/08_strict_family_mode.bats
# Integration Test: Strict Family Mode Logic
#
# Responsibility: Verify that naming a sumfile after a specific family
# (e.g., shasums.txt) disables automatic fallback to other families (e.g., Blake2),
# ensuring strict adherence to the user's implied context.

load '../test_helper'

setup() {
  load_lib "constants.sh"

  # 1. Sandbox Setup
  TEST_DIR="$(mktemp -d "${BATS_TMPDIR}/checkit_strict_XXXXXX")"
  DATA_FILE="${TEST_DIR}/data.iso"
  touch "$DATA_FILE"

  # 64-char hash (Ambigous: SHA-256 or BLAKE2-256)
  HASH_64=$(printf 'a%.0s' {1..64})

  # 2. Setup Mocks
  MOCK_BIN_DIR="${TEST_DIR}/bin"
  LOG_FILE="${TEST_DIR}/strict_calls.log"
  mkdir -p "$MOCK_BIN_DIR"

  # Mock SHA-256 to ALWAYS FAIL
  cat <<EOF >"$MOCK_BIN_DIR/sha256sum"
#!/bin/bash
cat > /dev/null
echo "SHA256SUM_CALLED" >> "$LOG_FILE"
exit 1
EOF
  chmod +x "$MOCK_BIN_DIR/sha256sum"
  cp "$MOCK_BIN_DIR/sha256sum" "$MOCK_BIN_DIR/shasum"

  # Mock B2SUM to ALWAYS SUCCEED
  cat <<EOF >"$MOCK_BIN_DIR/b2sum"
#!/bin/bash
cat > /dev/null
echo "B2SUM_CALLED" >> "$LOG_FILE"
echo "ba5eba11...  $DATA_FILE"
exit 0
EOF
  chmod +x "$MOCK_BIN_DIR/b2sum"

  # 3. Inject mocks into PATH
  export PATH="$MOCK_BIN_DIR:$PATH"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "Integration: Neutral filename (checksums.txt) ALLOWS fallback to Blake2" {
  # Scenario: Generic filename does not imply a specific family.
  local sumfile="${TEST_DIR}/checksums.txt"
  echo "$HASH_64  $DATA_FILE" >"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  assert_success
  # Should have recovered using Blake2
  assert_output --partial "[OK]"
  assert_output --partial "(blake2-256)"

  # Verify both were called
  run grep "SHA256SUM_CALLED" "$LOG_FILE"
  assert_success
  run grep "B2SUM_CALLED" "$LOG_FILE"
  assert_success
}

@test "Integration: Explicit family filename (shasums.txt) FORBIDS fallback to Blake2" {
  # Scenario: Filename "shasums.txt" implies the user ONLY wants SHA checks.
  local sumfile="${TEST_DIR}/shasums.txt"
  echo "$HASH_64  $DATA_FILE" >"$sumfile"

  run "$CHECKIT_EXEC" -c "$sumfile"

  # Should FAIL because SHA failed and Blake2 fallback is forbidden by context
  assert_failure "$EX_INTEGRITY_FAIL"
  assert_output --partial "[FAILED]"
  assert_output --partial "(sha256)"

  # Ensure Blake2 was never even mentioned or tried
  refute_output --partial "blake2"

  run grep "SHA256SUM_CALLED" "$LOG_FILE"
  assert_success

  # CRITICAL: B2SUM should NEVER be called in strict family mode
  run grep "B2SUM_CALLED" "$LOG_FILE"
  assert_failure
}
