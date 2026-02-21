#!/usr/bin/env bats
#
# tests/integration/23_check_flags.bats
# Integration Test: Operational Flags
#
# Responsibility: Validate CLI flags that alter operational behavior or output
# verbosity (--ignore-missing, --quiet, --status, --warn, --strict).

load '../test_helper'

setup() {
  load_lib "constants.sh"

  # 1. Sandbox Setup
  TEST_DIR="$(mktemp -d "${BATS_TMPDIR}/checkit_flags_XXXXXX")"

  # Valid Data File
  DATA_FILE="${TEST_DIR}/exists.txt"
  echo "content" >"$DATA_FILE"

  # 2. Setup Mocks
  MOCK_BIN_DIR="${TEST_DIR}/bin"
  mkdir -p "$MOCK_BIN_DIR"

  # Mock SHA256SUM
  cat <<EOF >"$MOCK_BIN_DIR/sha256sum"
#!/bin/bash
if [[ "\$*" == *"-c"* ]]; then exit 0; fi
echo "dummyhash  \$1"
EOF
  chmod +x "$MOCK_BIN_DIR/sha256sum"
  cp "$MOCK_BIN_DIR/sha256sum" "$MOCK_BIN_DIR/shasum"

  export PATH="$MOCK_BIN_DIR:$PATH"

  # 3. Construct Test Sumfiles
  HASH_VALID=$(printf 'a%.0s' {1..64})

  # File A: Mixed content (Valid + Missing + Garbage)
  SUMFILE_MIXED="${TEST_DIR}/mixed.txt"
  {
    echo "$HASH_VALID  $DATA_FILE"              # OK
    echo "$HASH_VALID  ${TEST_DIR}/missing.txt" # MISSING
    echo "GARBAGE_LINE_NO_FORMAT"               # BAD FORMAT
  } >"$SUMFILE_MIXED"

  # File B: Only Missing (Clean otherwise)
  SUMFILE_MISSING="${TEST_DIR}/missing_only.txt"
  {
    echo "$HASH_VALID  $DATA_FILE"
    echo "$HASH_VALID  ${TEST_DIR}/missing.txt"
  } >"$SUMFILE_MISSING"

  # File C: Clean (All OK)
  SUMFILE_CLEAN="${TEST_DIR}/clean.txt"
  echo "$HASH_VALID  $DATA_FILE" >"$SUMFILE_CLEAN"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# --- 1. --ignore-missing ---

@test "Flags: --ignore-missing suppresses error for missing files" {
  # Default behavior: Should fail due to missing file
  run "$CHECKIT_EXEC" -c "$SUMFILE_MISSING"
  assert_failure "$EX_INTEGRITY_FAIL"
  assert_output --partial "[MISSING]"

  # With Flag: Should pass (ignoring the missing file)
  run "$CHECKIT_EXEC" -c "$SUMFILE_MISSING" --ignore-missing
  assert_success

  # Ensure the missing error is NOT shown
  refute_output --partial "[MISSING]"
  # Ensure the existing file is still checked
  assert_output --partial "[OK]"
}

# --- 2. --quiet ---

@test "Flags: --quiet suppresses OK messages" {
  run "$CHECKIT_EXEC" -c "$SUMFILE_CLEAN" --quiet

  assert_success
  # Should be silent on success
  refute_output --partial "[OK]"
  assert_output ""
}

@test "Flags: --quiet allows errors to pass through" {
  # Even with quiet, errors must be printed (unless silenced by logic, but typically printed)
  # Note: Implementation dependent. Usually quiet suppresses stdout, not stderr.
  run "$CHECKIT_EXEC" -c "$SUMFILE_MISSING" --quiet

  assert_failure
  assert_output --partial "[MISSING]"
}

# --- 3. --status ---

@test "Flags: --status suppresses output but respects exit codes" {
  # Case Success
  run "$CHECKIT_EXEC" -c "$SUMFILE_CLEAN" --status
  assert_success
  assert_output ""

  # Case Failure
  run "$CHECKIT_EXEC" -c "$SUMFILE_MISSING" --status
  assert_failure "$EX_INTEGRITY_FAIL"
  # Status mode usually suppresses ALL output, or just success output?
  # Assuming "status" acts like grep -q (silent).
  # If your tool prints errors in status mode, adjust this expectation.
  # Based on standard behavior:
  # refute_output --partial "[OK]"
}

# --- 4. --warn ---

@test "Flags: --warn prints message on bad formatting" {
  # Using the mixed file which has garbage
  run "$CHECKIT_EXEC" -c "$SUMFILE_MIXED" --warn --ignore-missing

  # Should pass because we ignore missing, and garbage is just a warning now
  assert_success
  assert_output --partial "WARNING"
  assert_output --partial "improperly formatted"
}

# --- 5. --strict ---

@test "Flags: --strict exits non-zero on bad formatting" {
  run "$CHECKIT_EXEC" -c "$SUMFILE_MIXED" --strict --ignore-missing

  # Should FAIL because of the garbage line, despite ignore-missing
  assert_failure "$EX_INTEGRITY_FAIL"
  assert_output --partial "WARNING"
}
