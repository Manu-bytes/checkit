#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"
  source "$PROJECT_ROOT/lib/core/algorithm_chooser.sh"
}

# --- SECTION 1: Basic Algorithm Identification by Length ---
@test "Core: identify_algorithm returns error on invalid length" {
  local input_hash="12345" # Too short
  run core::identify_algorithm "$input_hash"
  assert_failure "$EX_OPERATIONAL_ERROR"
}

@test "Core: identify_algorithm detects MD5 by length (32 chars)" {
  local input_hash="d41d8cd98f00b204e9800998ecf8427e"
  run core::identify_algorithm "$input_hash"
  assert_success
  assert_output "md5"
}

@test "Core: identify_algorithm detects SHA-1 by length (40 chars)" {
  local input_hash="a9993e364706816aba3e25717850c26c9cd0d89d"
  run core::identify_algorithm "$input_hash"
  assert_success
  assert_output "sha1"
}

@test "Core: identify_algorithm detects SHA-224 by length (56 chars)" {
  local input_hash="d14a028c2a3a2bc9476102bb288234c415a2b01f828ea62ac5b3e42f"
  run core::identify_algorithm "$input_hash"
  assert_success
  assert_output "sha224"
}

@test "Core: identify_algorithm detects SHA-256 by length (64 chars)" {
  local input_hash="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  run core::identify_algorithm "$input_hash"
  assert_success
  assert_output "sha256"
}

@test "Core: identify_algorithm detects SHA-384 by length (96 chars)" {
  local input_hash="38b060a751ac96384cd9327eb1b1e36a21fdb71114be07434c0cc7bf63f6e1da274edebfe76f65fbd51ad2f14898b95b"
  run core::identify_algorithm "$input_hash"
  assert_success
  assert_output "sha384"
}

@test "Core: identify_algorithm detects SHA-512 by length (128 chars)" {
  local input_hash="cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"
  run core::identify_algorithm "$input_hash"
  assert_success
  assert_output "sha512"
}

# --- SECTION 2: Collision Resolution (Hints) ---
@test "Core: identify_algorithm resolves BLAKE2-128 via hint" {
  local hash_32="29f0aacdca7198ed8cc3cde41fea4410"
  run core::identify_algorithm "$hash_32" "B2SUMS"
  assert_success
  assert_output "blake2-128"
}

@test "Core: identify_algorithm resolves BLAKE2-160 via hint" {
  local hash_40="a300b95272e7ccd713c5abbbe166160c229d1dd8"
  run core::identify_algorithm "$hash_40" "B2SUMS"
  assert_success
  assert_output "blake2-160"
}

@test "Core: identify_algorithm resolves BLAKE2-224 via hint" {
  local hash_56="7b8759a275e4ec863cff679a974f1e818bbfb7b1e0ebf7b6fee9ee11"
  run core::identify_algorithm "$hash_56" "B2SUMS"
  assert_success
  assert_output "blake2-224"
}

@test "Core: identify_algorithm resolves BLAKE2-256 via hint" {
  local hash_64="3e02b2d6f92222549c672c8bc91fff9b87139fd77b725f8c387888922339cacd"
  run core::identify_algorithm "$hash_64" "B2SUMS"
  assert_success
  assert_output "blake2-256"
}

@test "Core: identify_algorithm resolves BLAKE2-384 via hint" {
  local hash_96="719c85c5fff5393aaa5a6828be3956cec69e53527c4529c439311b24359c9e901d99719373209159f6fe527f1dc81aa9"
  run core::identify_algorithm "$hash_96" "B2SUMS"
  assert_success
  assert_output "blake2-384"
}

@test "Core: identify_algorithm resolves BLAKE2 (512) via hint" {
  local hash_128="cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"
  run core::identify_algorithm "$hash_128" "archive.b2"
  assert_success
  assert_output "blake2"
}

# --- SECTION 3: Smart File Scanning (GPG, BSD, GNU) ---
@test "Core: identify_from_file detects SHA-256 from standard sumfile" {
  local sumfile="test_std.txt"
  echo "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  file" >"$sumfile"

  run core::identify_from_file "$sumfile"

  rm "$sumfile"
  assert_success
  assert_output "sha256"
}

@test "Core: identify_from_file detects SHA-512 from BSD-style tag" {
  local sumfile="test_bsd_sha.txt"
  echo "SHA512 (data.tar) = cf83e135..." >"$sumfile"

  run core::identify_from_file "$sumfile"

  rm "$sumfile"
  assert_success
  assert_output "sha512"
}

@test "Core: identify_from_file detects BLAKE2 from BSD-style tag (BLAKE2b variant)" {
  local sumfile="test_bsd_blake.txt"
  # Note: specifically testing "BLAKE2b" with the 'b' suffix
  echo "BLAKE2b (data.tar) = cf83e135..." >"$sumfile"

  run core::identify_from_file "$sumfile"

  rm "$sumfile"
  assert_success
  # Expecting normalized output "blake2" (for b2sum compatibility)
  assert_output "blake2"
}

@test "Core: identify_from_file detects algo inside PGP Signed Message (Fedora style)" {
  local sumfile="fedora_test.CHECKSUM"
  {
    echo "-----BEGIN PGP SIGNED MESSAGE-----"
    echo "Hash: SHA256"
    echo ""
    echo "SHA256 (Fedora.iso) = 28b6..."
  } >"$sumfile"

  run core::identify_from_file "$sumfile"

  rm "$sumfile"
  assert_success
  assert_output "sha256"
}
