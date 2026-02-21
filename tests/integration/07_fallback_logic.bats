#!/usr/bin/env bats
#
# tests/integration/07_fallback_logic.bats
# Integration Test: Automatic Algorithm Fallback
#
# Responsibility: Verify that when a primary algorithm guess (e.g., SHA-256)
# fails, the system automatically attempts a fallback (e.g., BLAKE2-256)
# before reporting failure, provided the hash length matches both.

load '../test_helper'

setup() {
  load_lib "constants.sh"

  # 1. Create sandbox
  TEST_DIR="$(mktemp -d "${BATS_TMPDIR}/checkit_fallback_XXXXXX")"
  DATA_FILE="${TEST_DIR}/data.iso"
  touch "$DATA_FILE"

  # 2. Setup neutral sumfile (64 chars could be SHA-256 or BLAKE2-256)
  HASH_64=$(printf 'a%.0s' {1..64})
  NEUTRAL_SUMFILE="${TEST_DIR}/neutral_hashes.txt"
  echo "$HASH_64  $DATA_FILE" >"$NEUTRAL_SUMFILE"

  # 3. Setup Mocks
  MOCK_BIN_DIR="${TEST_DIR}/bin"
  LOG_FILE="${TEST_DIR}/fallback_calls.log"
  mkdir -p "$MOCK_BIN_DIR"

  # Create a Mock for SHA-256 that ALWAYS FAILS
  # This simulates a mismatch or the wrong algorithm being guessed first.
  cat <<EOF >"$MOCK_BIN_DIR/sha256sum"
#!/bin/bash
cat > /dev/null
echo "SHA256SUM_CALLED" >> "$LOG_FILE"
exit 1
EOF
  chmod +x "$MOCK_BIN_DIR/sha256sum"

  # Create a Mock for BLAKE2 (b2sum) that ALWAYS SUCCEEDS
  cat <<EOF >"$MOCK_BIN_DIR/b2sum"
#!/bin/bash
cat > /dev/null
echo "B2SUM_CALLED" >> "$LOG_FILE"
echo "ba5eba11...  $DATA_FILE" # Simulate standard output
exit 0
EOF
  chmod +x "$MOCK_BIN_DIR/b2sum"

  # Ensure shasum is also mocked to fail to avoid Perl fallback bypass
  cp "$MOCK_BIN_DIR/sha256sum" "$MOCK_BIN_DIR/shasum"

  # 4. Inject mocks into PATH
  export PATH="$MOCK_BIN_DIR:$PATH"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "Integration: checkit falls back to BLAKE2-256 if SHA-256 verification fails" {
  # Execution
  run "$CHECKIT_EXEC" -c "$NEUTRAL_SUMFILE"

  # Assertions: The overall command should succeed because fallback worked
  assert_success

  # It should report OK using the fallback algorithm in the UI
  assert_output --partial "[OK]"
  assert_output --partial "(blake2-256)"

  # It should NOT report any failure to the user during the retry
  refute_output --partial "FAILED"

  # Verify the internal execution flow via logs
  # It must have called SHA256 first, then B2SUM
  run grep "SHA256SUM_CALLED" "$LOG_FILE"
  assert_success

  run grep "B2SUM_CALLED" "$LOG_FILE"
  assert_success
}

@test "Integration: checkit reports final failure if both primary and fallback fail" {
  # Modify B2SUM to also fail
  cat <<EOF >"${MOCK_BIN_DIR}/b2sum"
#!/bin/bash
echo "B2SUM_CALLED" >> "$LOG_FILE"
exit 1
EOF

  run "$CHECKIT_EXEC" -c "$NEUTRAL_SUMFILE"

  # Now it must fail
  assert_failure "$EX_INTEGRITY_FAIL"
  assert_output --partial "FAILED"

  run grep "B2SUM_CALLED" "$LOG_FILE"
  assert_success
}
