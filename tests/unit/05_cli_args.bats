#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"
  source "$PROJECT_ROOT/lib/cli/args.sh"
}

# Explicit Check Mode (-c)
@test "CLI: -c triggers Check Mode for sumfiles" {
  cli::parse_args "-c" "checksums.txt"

  assert_equal "$__CLI_MODE" "check"
  assert_equal "${__CLI_FILES[0]}" "checksums.txt"
}

# Implicit Verify String Mode (File + Hash)
@test "CLI: Two positional args trigger Verify String Mode" {
  # checkit <file> <hash>
  cli::parse_args "distro.iso" "a1b2c3d4"

  assert_equal "$__CLI_MODE" "verify_string"
  assert_equal "$__CLI_FILE" "distro.iso"
  assert_equal "$__CLI_HASH" "a1b2c3d4"
}

# Implicit Create Mode (File + Something)
@test "CLI: Single file triggers Create Mode (default algo)" {
  # checkit <file>
  cli::parse_args "image.png"

  assert_equal "$__CLI_MODE" "create"
  assert_equal "${__CLI_FILES[0]}" "image.png"
  assert_equal "$__CLI_ALGO" "sha256" # Default
}

@test "CLI: Single file with --algo triggers Create Mode" {
  # checkit <file> --algo md5
  cli::parse_args "image.png" "--algo" "md5"

  assert_equal "$__CLI_MODE" "create"
  assert_equal "${__CLI_FILES[0]}" "image.png"
  assert_equal "$__CLI_ALGO" "md5"
}

# Additional Flags
@test "CLI: --copy flag is detected in Create Mode" {
  cli::parse_args "passwords.txt" "--copy"

  assert_equal "$__CLI_MODE" "create"
  assert_equal "$__CLI_COPY" "true"
}

@test "CLI: --check flag is detected with long option" {
  cli::parse_args "--check" "sums.txt"
  assert_equal "$__CLI_MODE" "check"
}
