#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"

  DATA_FILE="exists.txt"
  touch "$DATA_FILE"

  HASH_VALID=$(printf 'a%.0s' {1..64})

  MOCK_BIN_DIR="$BATS_TMPDIR/checkit_mocks_flags"
  LOG_FILE="$BATS_TMPDIR/flags_calls.log"
  rm -f "$LOG_FILE"

  setup_integration_mocks "$MOCK_BIN_DIR" "$LOG_FILE"
  export PATH="$MOCK_BIN_DIR:$PATH"

  SUMFILE="flags_test.txt"
  {
    echo "$HASH_VALID  $DATA_FILE"
    echo "GARBAGE_LINE_NO_FORMAT"
    echo "$HASH_VALID  missing.txt"
  } >>"$SUMFILE"
  CLEAN_SUMFILE="clean.txt"
}

teardown() {
  rm -rf "$MOCK_BIN_DIR"
  rm -f "$DATA_FILE" "$SUMFILE" "$CLEAN_SUMFILE"
}

# 1. --ignore-missing

@test "Flags: --ignore-missing suppresses error for missing files" {
  run "$CHECKIT_EXEC" -c "$SUMFILE"
  assert_failure "$EX_INTEGRITY_FAIL"
  assert_output --partial "[MISSING]"

  run "$CHECKIT_EXEC" -c "$SUMFILE" --ignore-missing
  assert_success
  refute_output --partial "[MISSING]"
  assert_output --partial "[OK] exists.txt"
}

# 2. --quiet

@test "Flags: --quiet suppresses OK messages" {
  run "$CHECKIT_EXEC" -c "$SUMFILE" --quiet --ignore-missing

  assert_success
  refute_output --partial "[OK]"
}

# 3. --status

@test "Flags: --status suppresses OK output but shows system errors" {
  echo "$HASH_VALID  $DATA_FILE" >"$CLEAN_SUMFILE"

  run "$CHECKIT_EXEC" -c "$CLEAN_SUMFILE" --status
  assert_success
  assert_output ""

  run "$CHECKIT_EXEC" -c "$SUMFILE" --status

  assert_failure "$EX_INTEGRITY_FAIL"

  assert_output --partial "[MISSING] missing.txt"

  refute_output --partial "[OK]"
}

# 4. --warn

@test "Flags: --warn prints message to stderr on bad formatting" {
  run "$CHECKIT_EXEC" -c "$SUMFILE" --warn --ignore-missing

  assert_success
  assert_output --partial "WARNING: 1 line is improperly formatted"
}

# 5. --strict

@test "Flags: --strict exits non-zero on bad formatting" {
  run "$CHECKIT_EXEC" -c "$SUMFILE" --strict --ignore-missing

  assert_failure "$EX_INTEGRITY_FAIL"
  assert_output --partial "WARNING: 1 line is improperly formatted"
}
