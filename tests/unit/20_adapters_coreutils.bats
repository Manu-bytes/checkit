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
  load_lib "core/algorithm_chooser.sh" # Dependency for parser
  load_lib "core/parser.sh"            # Required by check_list

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

# --- Helper Functions ---

@test "Adapter: get_algo_length maps algorithm names to hex string lengths" {
  run hash_adapter::get_algo_length "md5"
  assert_output "32"

  run hash_adapter::get_algo_length "sha256"
  assert_output "64"

  run hash_adapter::get_algo_length "blake2-256"
  assert_output "64"

  run hash_adapter::get_algo_length "blake2b"
  assert_output "128"
}

@test "Adapter: get_fallback_algo maps primary algorithms to secure fallbacks" {
  run hash_adapter::get_fallback_algo "sha256"
  assert_output "blake2-256"

  run hash_adapter::get_fallback_algo "sha512"
  assert_output "blake2"
}

# --- Check List Engine ---

@test "Adapter: check_list processes a valid sumfile successfully" {
  # Mock UI functions to prevent terminal output during tests
  ui::log_file_status() { :; }
  ui::log_report_summary() { :; }
  core::identify_from_file() { return 1; }

  local sumfile="${BATS_TMPDIR}/valid_sums.txt"
  local target_file="${BATS_TMPDIR}/target_ok.txt"
  touch "$target_file"

  # Create a valid 64-character (sha256) hash line
  local hash
  hash=$(printf 'a%.0s' {1..64})
  echo "$hash  $target_file" >"$sumfile"

  run hash_adapter::check_list "auto" "$sumfile"

  assert_success
  rm -f "$sumfile" "$target_file"
}

@test "Adapter: check_list fails on missing files by default" {
  ui::log_file_status() { :; }
  ui::log_report_summary() { :; }
  core::identify_from_file() { return 1; }

  local sumfile="${BATS_TMPDIR}/missing_sums.txt"
  local hash
  hash=$(printf 'b%.0s' {1..64})
  echo "$hash  /path/to/nonexistent/file.txt" >"$sumfile"

  __CLI_IGNORE_MISSING=false
  run hash_adapter::check_list "auto" "$sumfile"

  assert_failure "$EX_INTEGRITY_FAIL"
  rm -f "$sumfile"
}

@test "Adapter: check_list ignores missing files when flag is set" {
  ui::log_file_status() { :; }
  ui::log_report_summary() { :; }
  core::identify_from_file() { return 1; }

  local sumfile="${BATS_TMPDIR}/ignore_sums.txt"
  local hash
  hash=$(printf 'c%.0s' {1..64})
  echo "$hash  /path/to/nonexistent/file.txt" >"$sumfile"

  # Override global CLI state
  __CLI_IGNORE_MISSING=true
  run hash_adapter::check_list "auto" "$sumfile"

  # Should succeed because the missing file was ignored and there are no other errors
  assert_success
  rm -f "$sumfile"
}

@test "Adapter: check_list aborts strictly on GPG bad signature" {
  ui::log_file_status() { :; }
  ui::log_report_summary() { :; }
  ui::log_critical() { :; }
  core::identify_from_file() { return 1; }

  # Mock GPG adapter to simulate a bad signature detection on the target file
  gpg::detect_signature() { return 0; }
  gpg::verify_detached() { return "$EX_SECURITY_FAIL"; }

  local sumfile="${BATS_TMPDIR}/gpg_sums.txt"
  local target_file="${BATS_TMPDIR}/target_gpg.txt"
  touch "$target_file"

  local hash
  hash=$(printf 'd%.0s' {1..64})
  echo "$hash  $target_file" >"$sumfile"

  # Enforce strict security mode
  __CLI_STRICT_SECURITY=true

  run hash_adapter::check_list "auto" "$sumfile"

  assert_failure "$EX_SECURITY_FAIL"
  rm -f "$sumfile" "$target_file"
}
