#!/usr/bin/env bats
#
# tests/unit/20_adapters_coreutils.bats
# Hash Adapter Unit Tests.
#
# Responsibility: Verify that the adapter correctly orchestrates calls to
# native binaries (sha256sum, b2sum, etc.) and parses their exit codes.
# shellcheck disable=SC2329

load '../test_helper'

setup() {
  load_lib "constants.sh"
  load_lib "adapters/hash_adapter.sh"

  # Create a dummy test file
  touch "${BATS_TMPDIR}/test_gen.txt"
  TEST_FILE="${BATS_TMPDIR}/test_gen.txt"

  # --- MOCKS ---
  # Define mocks locally to avoid polluting the global namespace.
  # These simple mocks simulate success/failure for the adapter logic.

  # Mock: sha256sum
  # Logic: If arg contains "-c", act as verify (silent success).
  #        Else, act as calculate (output hash).
  sha256sum() {
    if [[ "$*" == *"-c"* ]]; then return 0; fi
    echo "mock_sha256_hash  $TEST_FILE"
  }
  export -f sha256sum

  # Mock: b2sum (same logic)
  b2sum() {
    if [[ "$*" == *"-c"* ]]; then return 0; fi
    echo "mock_b2_hash  $TEST_FILE"
  }
  export -f b2sum

  # Mock: shasum (Perl script wrapper)
  shasum() {
    if [[ "$*" == *"-c"* ]]; then return 0; fi
    echo "mock_shasum_hash  $TEST_FILE"
  }
  export -f shasum
}

teardown() {
  rm -f "$TEST_FILE"
}

# --- Verification Logic ---

@test "Adapter: verify calls native sha256sum correctly" {
  # 64 chars = sha256
  local hash
  hash=$(printf 'a%.0s' {1..64})

  run hash_adapter::verify "sha256" "$TEST_FILE" "$hash"
  assert_success
}

@test "Adapter: verify fails when underlying binary returns error" {
  local hash
  hash=$(printf 'a%.0s' {1..64})

  # Override mock to simulate corruption
  sha256sum() { return 1; }
  export -f sha256sum

  shasum() { return 1; }
  export -f sha256sum

  run hash_adapter::verify "sha256" "$TEST_FILE" "$hash"
  assert_failure "$EX_INTEGRITY_FAIL"
}

@test "Adapter: verify returns operational error if file missing" {
  run hash_adapter::verify "sha256" "non_existent_file.txt" "hash"
  assert_failure "$EX_OPERATIONAL_ERROR"
}

@test "Adapter: verify fails on length mismatch (b2 alias strictness)" {
  # 'blake2' implies 512 bits (128 chars).
  # Providing a short hash (3 chars) should trigger integrity fail before calling binary.
  local short_hash="abc"
  run hash_adapter::verify "blake2" "$TEST_FILE" "$short_hash"
  assert_failure "$EX_INTEGRITY_FAIL"
}

@test "Adapter: verify fails on mismatched alias length (b2-128 vs long hash)" {
  # b2-128 = 32 chars. Providing 56 chars (224 bits) should fail.
  local long_hash
  long_hash=$(printf '1%.0s' {1..56})
  run hash_adapter::verify "blake2-128" "$TEST_FILE" "$long_hash"
  assert_failure "$EX_INTEGRITY_FAIL"
}

# --- Calculation Logic ---

@test "Adapter: calculate generates proper output format" {
  run hash_adapter::calculate "sha256" "$TEST_FILE"

  assert_success
  # Must match the mocked output
  if [[ "$CHECKIT_FORCE_PERL" == "true" ]]; then
    assert_output "mock_shasum_hash  $TEST_FILE"
  else
    assert_output "mock_sha256_hash  $TEST_FILE"
  fi
}

@test "Adapter: calculate handles missing file gracefully" {
  run hash_adapter::calculate "sha256" "missing.txt"
  assert_failure "$EX_OPERATIONAL_ERROR"
}
