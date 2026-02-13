#!/usr/bin/env bats
#
# tests/unit/05_cli_args.bats
# CLI Argument Parser Unit Tests.
#
# Responsibility: Verify that command line arguments correctly populate
# global configuration variables (__CLI_*).
# shellcheck disable=SC2329

load '../test_helper'

setup() {
  # 1. Load Dependencies via Helper
  # ui.sh is required because args.sh calls ui::log_error/warning
  load_lib "constants.sh"
  load_lib "cli/ui.sh"
  load_lib "cli/args.sh"

  # 2. Mock UI Output
  # Prevent error messages from cluttering the test output.
  # We only care about the state of global variables.
  ui::log_error() { :; }
  ui::log_warning() { :; }
}

# --- Mode Inference Tests ---

@test "CLI: -c triggers Check Mode for sumfiles" {
  cli::parse_args "-c" "checksums.txt"

  assert_equal "$__CLI_MODE" "check"
  assert_equal "${__CLI_FILES[0]}" "checksums.txt"
}

@test "CLI: Two positional args trigger Verify String Mode" {
  # checkit <file> <hash>
  cli::parse_args "distro.iso" "a1b2c3d4"

  assert_equal "$__CLI_MODE" "verify_string"
  assert_equal "$__CLI_FILE" "distro.iso"
  assert_equal "$__CLI_HASH" "a1b2c3d4"
}

@test "CLI: Single file triggers Create Mode (default algo)" {
  # checkit <file>
  cli::parse_args "image.png"

  assert_equal "$__CLI_MODE" "create"
  assert_equal "${__CLI_FILES[0]}" "image.png"
  # Default algorithm defined in args.sh
  assert_equal "$__CLI_ALGO" "sha256"
}

# --- Flag Logic Tests ---

@test "CLI: --algo overrides default algorithm" {
  cli::parse_args "image.png" "--algo" "md5"

  assert_equal "$__CLI_MODE" "create"
  assert_equal "${__CLI_FILES[0]}" "image.png"
  assert_equal "$__CLI_ALGO" "md5"
  assert_equal "$__CLI_ALGO_SET" "true"
}

@test "CLI: --copy flag enables clipboard" {
  cli::parse_args "passwords.txt" "--copy"
  assert_equal "$__CLI_COPY" "true"
}

@test "CLI: --verify-sign sets strict security" {
  cli::parse_args "-c" "sums.txt" "--verify-sign"
  assert_equal "$__CLI_STRICT_SECURITY" "true"
}

@test "CLI: --sign enables clear signing mode" {
  cli::parse_args "file.txt" "--sign"
  assert_equal "$__CLI_SIGN" "true"
  assert_equal "$__CLI_SIGN_MODE" "clear"
}

@test "CLI: --detach-sign enables detach mode" {
  cli::parse_args "file.txt" "--detach-sign"
  assert_equal "$__CLI_SIGN" "true"
  assert_equal "$__CLI_SIGN_MODE" "detach"
}

@test "CLI: --output accepts valid formats (json)" {
  cli::parse_args "file.txt" "--output" "json"
  assert_equal "$__CLI_OUTPUT_FMT" "json"
}

@test "CLI: --output rejects invalid formats" {
  run cli::parse_args "file.txt" "--output" "invalid_fmt"
  assert_failure "$EX_OPERATIONAL_ERROR"
}

@test "CLI: --all flag sets all algorithms boolean" {
  cli::parse_args "file.txt" "--all"
  assert_equal "$__CLI_ALL_ALGOS" "true"
}
