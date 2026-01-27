#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"
  source "$PROJECT_ROOT/lib/adapters/coreutils.sh"
}

@test "Adapter: coreutils::verify constructs correct command/pipe for SHA-256" {
  # Mocking: Simulate sha256sum reading from STDIN
  function sha256sum() {
    # We read what the pipe sends us
    local input
    input=$(cat)

    # We verify that the input has the correct format
    if [[ "$input" == *"good_hash"* ]] && [[ "$input" == *"test_file.txt"* ]]; then
      return 0
    else
      return 1
    fi
  }
  export -f sha256sum

  local algo="sha256"
  local file="test_file.txt"
  local hash="good_hash"

  # We create a dummy file to pass the existence validation (-f)
  touch "$file"

  run coreutils::verify "$algo" "$file" "$hash"

  rm "$file" # clean

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
