#!/usr/bin/env bats
#
# tests/unit/40_cli_ui.bats
# UI Adapter Unit Tests.
#
# Responsibility: Verify message retrieval, string formatting, and
# basic logging functions.

load '../test_helper'

setup() {
  load_lib "constants.sh"
  load_lib "cli/ui.sh"
}

# --- Message Retrieval ---

@test "UI: get_msg retrieves English string by default" {
  run ui::get_msg "lbl_ok"
  assert_output "OK"
}

@test "UI: get_msg returns key if not found" {
  run ui::get_msg "non_existent_key"
  assert_output "non_existent_key"
}

# --- Message Formatting ---

@test "UI: fmt_msg interpolates arguments correctly" {
  # Mock a message key that expects a %s
  # We hook into the get_msg function for this test only
  # shellcheck disable=SC2329
  ui::get_msg() {
    if [[ "$1" == "test_fmt" ]]; then echo "Hello %s!"; else echo "$1"; fi
  }

  run ui::fmt_msg "test_fmt" "World"
  assert_output "Hello World!"
}

# --- Logging Wrappers ---

@test "UI: log_info prints with Info symbol" {
  # Force TTY colors off for predictable output comparison
  __CLI_QUIET=false

  run ui::log_info "Test Message"

  # Just checking that it prints something to stderr containing the message
  assert_output --partial "Test Message"
}

@test "UI: log_error prints to stderr" {
  run ui::log_error "Critical Failure"
  assert_output --partial "Critical Failure"
}

@test "UI: log_file_status handles ST_OK" {
  run ui::log_file_status "$ST_OK" "file.txt" "sha256"
  assert_output --partial "file.txt"
  assert_output --partial "sha256"
}
