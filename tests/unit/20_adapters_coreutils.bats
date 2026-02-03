#!/usr/bin/env bats

# shellcheck disable=SC2329
load '../libs/bats-support/load'
load '../libs/bats-assert/load'

# Load system under test
load '../../lib/constants.sh'
source "./lib/adapters/coreutils.sh"

setup() {
  touch test_gen.txt

  # Mock for sha256sum
  sha256sum() {
    local is_verify=false
    # Detect -c in any position
    for arg in "$@"; do
      if [[ "$arg" == "-c" ]]; then
        is_verify=true
        break
      fi
    done

    if [[ "$is_verify" == "true" ]]; then
      cat >/dev/null
      return 0
    else
      # Calculate mode: capture last argument (file)
      local file=""
      for arg in "$@"; do file="$arg"; done
      echo "mock_generated_hash  $file"
      return 0
    fi
  }
  export -f sha256sum

  # Mock for shasum
  shasum() {
    local is_verify=false
    for arg in "$@"; do
      if [[ "$arg" == "-c" ]]; then
        is_verify=true
        break
      fi
    done

    if [[ "$is_verify" == "true" ]]; then
      cat >/dev/null
      return 0
    else
      local file=""
      for arg in "$@"; do file="$arg"; done
      echo "mock_generated_hash  $file"
      return 0
    fi
  }
  export -f shasum

  # Mock for b2sum
  b2sum() {
    local is_verify=false
    for arg in "$@"; do
      if [[ "$arg" == "-c" ]]; then
        is_verify=true
        break
      fi
    done

    if [[ "$is_verify" == "true" ]]; then
      cat >/dev/null
      return 0
    else
      local file=""
      for arg in "$@"; do file="$arg"; done
      echo "mock_b2_hash  $file"
      return 0
    fi
  }
  export -f b2sum
}

teardown() {
  rm -f test_gen.txt
}

@test "Adapter: coreutils::verify constructs correct command/pipe for SHA-256" {
  # Generate a valid-length hash (64 chars)
  local valid_len_hash
  valid_len_hash=$(printf 'a%.0s' {1..64})

  run coreutils::verify "sha256" "test_gen.txt" "$valid_len_hash"
  assert_success
}

@test "Adapter: coreutils::verify fails when underlying command fails (integrity error)" {
  local valid_len_hash
  valid_len_hash=$(printf 'a%.0s' {1..64})

  # Override mocks locally to simulate failure
  sha256sum() { return 1; }
  export -f sha256sum
  shasum() { return 1; }
  export -f shasum

  run coreutils::verify "sha256" "test_gen.txt" "$valid_len_hash"
  assert_failure "$EX_INTEGRITY_FAIL"
}

@test "Adapter: coreutils::verify returns operational error if file missing" {
  run coreutils::verify "sha256" "missing_file.txt" "hash"
  assert_failure "$EX_OPERATIONAL_ERROR"
}

@test "Adapter: coreutils::calculate generates hash for file" {
  run coreutils::calculate "sha256" "test_gen.txt"

  # Output must match the format defined in the setup mocks
  assert_output "mock_generated_hash  test_gen.txt"
}

@test "Adapter: coreutils::calculate handles missing file" {
  run coreutils::calculate "sha256" "missing.txt"
  assert_failure "$EX_OPERATIONAL_ERROR"
}

@test "Adapter: coreutils::verify enforces strict length for aliases (b2/blake2-512)" {
  # 128 chars expected for blake2-512
  local short_hash="abc"
  run coreutils::verify "blake2" "test_gen.txt" "$short_hash"
  assert_failure "$EX_INTEGRITY_FAIL"
}

@test "Adapter: coreutils::verify fails on mismatched custom alias (b2-128 vs 224-bit hash)" {
  # b2-128 expects 32 chars. Input is 56 chars.
  local long_hash="11111111111111111111111111111111111111111111111111111111"
  run coreutils::verify "blake2-128" "test_gen.txt" "$long_hash"
  assert_failure "$EX_INTEGRITY_FAIL"
}
