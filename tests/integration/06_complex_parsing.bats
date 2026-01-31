#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"

  # Create dummy data file to simulate the ISO
  DATA_FILE="debian-12.11.0-amd64-netinst.iso"
  echo "Dummy ISO content for testing complex parsing" >"$DATA_FILE"

  # Calculate real hashes for the dummy file.
  # This ensures verification logic actually works and not just parsing.
  HASH_MD5=$(md5sum "$DATA_FILE" | awk '{print $1}')
  HASH_SHA1=$(sha1sum "$DATA_FILE" | awk '{print $1}')
  HASH_SHA256=$(sha256sum "$DATA_FILE" | awk '{print $1}')
  HASH_SHA512=$(sha512sum "$DATA_FILE" | awk '{print $1}')

  # 1. Standard Format Mixed (Like sumhasheg1)
  # Contains multiple algorithms for the same file in standard GNU format.
  MIXED_STD="mixed_std.txt"
  {
    echo "$HASH_MD5  $DATA_FILE"
    echo "$HASH_SHA1  $DATA_FILE"
    echo "$HASH_SHA256  $DATA_FILE"
    echo "$HASH_SHA512  $DATA_FILE"
  } >"$MIXED_STD"

  # 2. Reversed Format Mixed (Like sumhasheg2)
  # Format: "filename hash" (common in some lists or manual outputs).
  MIXED_REV="mixed_rev.txt"
  {
    echo "$DATA_FILE  $HASH_MD5"
    echo "$DATA_FILE $HASH_SHA256"
    echo "$DATA_FILE $HASH_SHA512"
  } >"$MIXED_REV"

  # 3. Binary Marker Mixed (Like sumhasheg3)
  # Format: "hash *filename" (* denotes binary mode in GNU tools).
  MIXED_BIN="mixed_bin.txt"
  {
    echo "$HASH_SHA256  *$DATA_FILE"
    echo "$HASH_MD5  *$DATA_FILE"
  } >"$MIXED_BIN"

  # 4. Wrapped/Special Char Format (Edge Case)
  # Simulating filenames or hashes wrapped in parenthesis/brackets.
  MIXED_SPECIAL="mixed_special.txt"
  {
    echo "($HASH_SHA256)  $DATA_FILE"
    echo "$DATA_FILE  <$HASH_MD5>"
  } >"$MIXED_SPECIAL"
}

teardown() {
  rm -f "$DATA_FILE" "mixed_std.txt" "mixed_rev.txt" "mixed_bin.txt" "mixed_special.txt"
}

@test "Integration: checkit handles mixed algorithms in standard format (sumhasheg1)" {
  run "$CHECKIT_EXEC" -c "$MIXED_STD"

  assert_success
  # Must verify ALL algorithms present in the file
  assert_output --partial "[OK] $DATA_FILE (md5)"
  assert_output --partial "[OK] $DATA_FILE (sha1)"
  assert_output --partial "[OK] $DATA_FILE (sha256)"
  assert_output --partial "[OK] $DATA_FILE (sha512)"
}

@test "Integration: checkit handles reversed format 'filename hash' (sumhasheg2)" {
  run "$CHECKIT_EXEC" -c "$MIXED_REV"

  assert_success
  assert_output --partial "[OK] $DATA_FILE (md5)"
  assert_output --partial "[OK] $DATA_FILE (sha256)"
  assert_output --partial "[OK] $DATA_FILE (sha512)"
}

@test "Integration: checkit handles binary '*' marker (sumhasheg3)" {
  run "$CHECKIT_EXEC" -c "$MIXED_BIN"

  assert_success
  assert_output --partial "[OK] $DATA_FILE (sha256)"
  assert_output --partial "[OK] $DATA_FILE (md5)"
}

@test "Integration: checkit parses hashes wrapped in special chars" {
  run "$CHECKIT_EXEC" -c "$MIXED_SPECIAL"

  # This test validates robustness against (hash) or <hash> formats
  assert_success
  assert_output --partial "[OK] $DATA_FILE (sha256)"
  assert_output --partial "[OK] $DATA_FILE (md5)"
}
