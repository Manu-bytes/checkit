#!/usr/bin/env bats

load '../test_helper'

setup() {
  # Path to the unit under test
  source "$PROJECT_ROOT/lib/constants.sh"
  source "$PROJECT_ROOT/lib/core/algorithm_chooser.sh"
}

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
  # 224 bits / 4 bits-per-char = 56 chars
  local input_hash="d14a028c2a3a2bc9476102bb288234c415a2b01f828ea62ac5b3e42f"

  run core::identify_algorithm "$input_hash"

  assert_success
  assert_output "sha224"
}

@test "Core: identify_algorithm detects SHA-256 by length (64 chars)" {
  # Simulation of a valid SHA-256 hash
  local input_hash="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

  run core::identify_algorithm "$input_hash"

  assert_success
  assert_output "sha256"
}

@test "Core: identify_algorithm detects SHA-384 by length (96 chars)" {
  # 384 bits / 4 bits-per-char = 96 chars
  local input_hash="a592a24af9a3637189d2d385848d799f92d47c481b31b3c9594aaf494957635706599b775432062562412803328114f4"

  run core::identify_algorithm "$input_hash"

  assert_success
  assert_output "sha384"
}

@test "Core: identify_algorithm detects SHA-512 by length (128 chars)" {
  # A 128-character dummy SHA-512 hash
  local input_hash="cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"

  run core::identify_algorithm "$input_hash"

  assert_success
  assert_output "sha512"
}
