#!/usr/bin/env bats

# shellcheck disable=SC2329
load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"
  source "$PROJECT_ROOT/lib/adapters/coreutils.sh"
}

@test "Adapter: coreutils::verify constructs correct command/pipe for SHA-256" {

  local valid_hash_64
  valid_hash_64=$(printf 'a%.0s' {1..64})

  # Mocking: Simulate sha256sum reading from STDIN
  function sha256sum() {
    # We read what the pipe sends us
    local input
    input=$(cat)

    # We verify that the input contains OUR hash and filename
    # Note: We hardcode the match logic to the variable we defined above
    if [[ "$input" == *"$valid_hash_64"* ]] && [[ "$input" == *"test_file.txt"* ]]; then
      return 0
    else
      return 1
    fi
  }
  export -f sha256sum
  export valid_hash_64

  local algo="sha256"
  local file="test_file.txt"
  local hash="$valid_hash_64"

  # We create a dummy file to pass the existence validation (-f)
  touch "$file"

  run coreutils::verify "$algo" "$file" "$hash"

  rm "$file"

  assert_success
}

@test "Adapter: coreutils::verify fails when underlying command fails (integrity error)" {
  function sha256sum() { return 1; }
  export -f sha256sum

  local algo="sha256"
  local file="dummy_file"
  touch "$file"

  run coreutils::verify "$algo" "$file" "bad_hash"

  rm "$file"

  assert_failure "$EX_INTEGRITY_FAIL"
}

@test "Adapter: coreutils::verify returns operational error if file missing" {
  local algo="sha256"
  local file="non_existent_file"

  run coreutils::verify "$algo" "$file" "any_hash"

  assert_failure "$EX_OPERATIONAL_ERROR"
}

# --- Tests for calculate (Generation) ---
@test "Adapter: coreutils::calculate generates hash for file" {
  # Sha256sum mock for generation
  function sha256sum() {
    # Standard behavior: prints "hash filename"
    echo "mock_generated_hash  $1"
    return 0
  }
  export -f sha256sum

  local file="test_gen.txt"
  touch "$file"
  local algo="sha256"

  run coreutils::calculate "$algo" "$file"
  rm "$file"

  assert_success
  assert_output "mock_generated_hash  test_gen.txt"
}

@test "Adapter: coreutils::calculate handles missing file" {
  local file="ghost.txt"
  local algo="sha256"

  run coreutils::calculate "$algo" "$file"

  assert_failure "$EX_OPERATIONAL_ERROR"
}

@test "Adapter: coreutils::verify enforces strict length for aliases (b2/blake2-512)" {
  local algo="b2"
  local file="test_aliases.txt"
  local hash_224
  hash_224=$(printf 'a%.0s' {1..56})

  touch "$file"

  run coreutils::verify "$algo" "$file" "$hash_224"

  rm "$file"

  assert_failure "$EX_INTEGRITY_FAIL"
}

@test "Adapter: coreutils::verify fails on mismatched custom alias (b2-128 vs 224-bit hash)" {
  local algo="b2-128"
  local file="test_mismatch.txt"
  local hash_224
  hash_224=$(printf 'a%.0s' {1..56})

  touch "$file"

  run coreutils::verify "$algo" "$file" "$hash_224"

  rm "$file"

  assert_failure "$EX_INTEGRITY_FAIL"
}
