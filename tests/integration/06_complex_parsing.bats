#!/usr/bin/env bats
#
# tests/integration/06_complex_parsing.bats
# Integration Test: Complex and Mixed Parsing
#
# Responsibility: Validate that checkit can process files containing mixed
# formats (Standard, Reversed, Binary, Wrapped) and multiple algorithms
# within the same checksum file.

load '../test_helper'

setup() {
  load_lib "constants.sh"

  # 1. Create a secure sandbox
  TEST_DIR="$(mktemp -d "${BATS_TMPDIR}/checkit_complex_XXXXXX")"

  # 2. Setup Data File (The ISO simulation)
  DATA_FILE="${TEST_DIR}/debian-12.iso"
  echo "Dummy ISO content for testing complex parsing" >"$DATA_FILE"

  # 3. Check System Dependencies
  # We skip if basic coreutils are not present to calculate real hashes
  if ! command -v sha256sum >/dev/null || ! command -v md5sum >/dev/null; then
    skip "System hash tools (sha256sum/md5sum) not found"
  fi

  # 4. Calculate Real Hashes for the dummy file
  local h_md5 h_sha1 h_sha256 h_sha512
  h_md5=$(md5sum "$DATA_FILE" | awk '{print $1}')
  h_sha1=$(sha1sum "$DATA_FILE" | awk '{print $1}')
  h_sha256=$(sha256sum "$DATA_FILE" | awk '{print $1}')
  h_sha512=$(sha512sum "$DATA_FILE" | awk '{print $1}')

  # 5. Generate Test Files inside Sandbox

  # Mixed Standard Format (GNU Style)
  MIXED_STD="${TEST_DIR}/mixed_std.txt"
  {
    echo "$h_md5  $DATA_FILE"
    echo "$h_sha1  $DATA_FILE"
    echo "$h_sha256  $DATA_FILE"
    echo "$h_sha512  $DATA_FILE"
  } >"$MIXED_STD"

  # Mixed Reversed Format (Filename Hash)
  MIXED_REV="${TEST_DIR}/mixed_rev.txt"
  {
    echo "$DATA_FILE  $h_md5"
    echo "$DATA_FILE $h_sha256"
    echo "$DATA_FILE $h_sha512"
  } >"$MIXED_REV"

  # Binary Marker Mixed (hash *filename)
  MIXED_BIN="${TEST_DIR}/mixed_bin.txt"
  {
    echo "$h_sha256  *$DATA_FILE"
    echo "$h_md5  *$DATA_FILE"
  } >"$MIXED_BIN"

  # Wrapped/Special Char Format
  MIXED_SPECIAL="${TEST_DIR}/mixed_special.txt"
  {
    echo "($h_sha256)  $DATA_FILE"
    echo "$DATA_FILE  <$h_md5>"
  } >"$MIXED_SPECIAL"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# --- Tests ---

@test "Integration: checkit handles mixed algorithms in standard format" {
  run "$CHECKIT_EXEC" -c "$MIXED_STD"

  assert_success
  # Verify each algorithm was correctly identified and passed
  assert_output --partial "[OK]"
  assert_output --partial "(md5)"
  assert_output --partial "(sha1)"
  assert_output --partial "(sha256)"
  assert_output --partial "(sha512)"
}

@test "Integration: checkit handles reversed format 'filename hash'" {
  run "$CHECKIT_EXEC" -c "$MIXED_REV"

  assert_success
  assert_output --partial "[OK]"
  assert_output --partial "(md5)"
  assert_output --partial "(sha256)"
  assert_output --partial "(sha512)"
}

@test "Integration: checkit handles binary '*' marker" {
  run "$CHECKIT_EXEC" -c "$MIXED_BIN"

  assert_success
  assert_output --partial "[OK]"
  assert_output --partial "(sha256)"
  assert_output --partial "(md5)"
}

@test "Integration: checkit parses hashes wrapped in special chars (parenthesis/brackets)" {
  run "$CHECKIT_EXEC" -c "$MIXED_SPECIAL"

  assert_success
  assert_output --partial "[OK]"
  assert_output --partial "(sha256)"
  assert_output --partial "(md5)"
}

@test "Integration: checkit ignores malformed lines but continues processing" {
  local malformed_file="${TEST_DIR}/malformed.txt"
  local h_sha256
  h_sha256=$(sha256sum "$DATA_FILE" | awk '{print $1}')

  {
    echo "this line is garbage"
    echo "$h_sha256  $DATA_FILE"
    echo ""
    echo "another invalid line"
  } >"$malformed_file"

  run "$CHECKIT_EXEC" -c "$malformed_file"

  # It should succeed verifying the one valid line
  assert_success
  assert_output --partial "[OK]"
  assert_output --partial "(sha256)"
}
