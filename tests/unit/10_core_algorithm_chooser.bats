#!/usr/bin/env bats
#
# tests/unit/10_core_algorithm_chooser.bats
# Algorithm Detection Logic Unit Tests.
#
# Responsibility: Validate heuristic detection of hash algorithms based on
# string length, filename hints, and file headers (BSD tags, Content-Hash).

load '../test_helper'

setup() {
  load_lib "constants.sh"
  load_lib "core/algorithm_chooser.sh"

  # Temporary file for file-based tests
  TEST_FILE="${BATS_TMPDIR}/checkit_test_chooser_$$"
}

teardown() {
  rm -f "$TEST_FILE"
}

# --- SECTION 1: Identification by Length (String Analysis) ---

@test "Core: identify_algorithm returns error on invalid length" {
  run core::identify_algorithm "12345" # Too short
  assert_failure "$EX_OPERATIONAL_ERROR"
}

@test "Core: identify_algorithm detects standard SHA family by length" {
  # MD5 (32 chars)
  run core::identify_algorithm "d41d8cd98f00b204e9800998ecf8427e"
  assert_success
  assert_output "md5"

  # SHA-1 (40 chars)
  run core::identify_algorithm "a9993e364706816aba3e25717850c26c9cd0d89d"
  assert_success
  assert_output "sha1"

  # SHA-256 (64 chars)
  run core::identify_algorithm "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  assert_success
  assert_output "sha256"

  # SHA-512 (128 chars)
  # Using a dummy 128-char string for brevity in test logic, assuming length check works
  local sha512_dummy
  sha512_dummy=$(printf 'a%.0s' {1..128})
  run core::identify_algorithm "$sha512_dummy"
  assert_success
  assert_output "sha512"
}

# --- SECTION 2: Collision Resolution (Hints) ---

@test "Core: identify_algorithm resolves BLAKE2 family via hint" {
  # 32 chars (MD5 vs BLAKE2-128)
  local hash_32="29f0aacdca7198ed8cc3cde41fea4410"
  run core::identify_algorithm "$hash_32" "B2SUMS"
  assert_success
  assert_output "blake2-128"

  # 64 chars (SHA-256 vs BLAKE2-256)
  local hash_64="3e02b2d6f92222549c672c8bc91fff9b87139fd77b725f8c387888922339cacd"
  run core::identify_algorithm "$hash_64" "my-blake.txt"
  assert_success
  assert_output "blake2-256"

  # 128 chars (SHA-512 vs BLAKE2b)
  local hash_128
  hash_128=$(printf 'b%.0s' {1..128})
  run core::identify_algorithm "$hash_128" "archive.b2"
  assert_success
  assert_output "blake2"
}

# --- SECTION 3: Smart File Scanning (BSD Tags) ---

@test "Core: identify_from_file detects SHA-512 from BSD-style tag" {
  echo "SHA512 (data.tar) = cf83e135..." >"$TEST_FILE"

  run core::identify_from_file "$TEST_FILE"
  assert_success
  assert_output "sha512"
}

@test "Core: identify_from_file detects BLAKE2 from BSD-style tag (BLAKE2b variant)" {
  # Note: specifically testing "BLAKE2b" casing normalization
  echo "BLAKE2b (data.tar) = cf83e135..." >"$TEST_FILE"

  run core::identify_from_file "$TEST_FILE"
  assert_success
  # Expecting normalized output "blake2" (for b2sum compatibility)
  assert_output "blake2"
}

# --- SECTION 4: Smart File Scanning (Headers) ---

@test "Core: identify_from_file prioritizes 'Content-Hash' header" {
  cat <<EOF >"$TEST_FILE"
-----BEGIN PGP SIGNED MESSAGE-----
Content-Hash: sha384

d04b98...  file.iso
-----BEGIN PGP SIGNATURE-----
EOF

  run core::identify_from_file "$TEST_FILE"
  assert_success
  assert_output "sha384"
}

@test "Core: identify_from_file ignores standard GPG 'Hash:' header (Conflict Scenario)" {
  # Scenario: GPG signature uses SHA512, but the file content hashes are SHA256.
  # We must NOT return SHA512 just because GPG uses it.
  cat <<EOF >"$TEST_FILE"
-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA512
Content-Hash: sha256

e3b0c4...  file.iso
-----BEGIN PGP SIGNATURE-----
EOF

  run core::identify_from_file "$TEST_FILE"
  assert_success
  assert_output "sha256"
}

@test "Core: identify_from_file fails if no explicit clues found" {
  # A file with just hashes, but identify_from_file looks for HEADERS/TAGS,
  # not content analysis (that's parser's job).
  cat <<EOF >"$TEST_FILE"
e3b0c442...  file.iso
EOF

  run core::identify_from_file "$TEST_FILE"
  assert_failure "$EX_OPERATIONAL_ERROR"
}
