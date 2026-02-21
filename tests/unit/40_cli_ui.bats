#!/usr/bin/env bats
#
# tests/unit/40_cli_ui.bats
# UI Adapter Unit Tests.
#
# Responsibility: Verify message retrieval, string formatting, and
# basic logging functions.
# shellcheck disable=SC2034

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

# --- Internationalization (i18n) ---

@test "UI: get_msg returns Spanish strings when UI_LANG is es" {
  # Override the global variable set during library load
  UI_LANG="es"

  run ui::get_msg "lbl_fail"
  assert_output "FALLO"

  run ui::get_msg "lbl_miss"
  assert_output "AUSENTE"
}

@test "UI: get_msg returns English strings when UI_LANG is en" {
  UI_LANG="en"

  run ui::get_msg "lbl_fail"
  assert_output "FAILED"

  run ui::get_msg "lbl_miss"
  assert_output "MISSING"
}

# --- Report Summary Logic ---

@test "UI: log_report_summary prints only non-zero counts" {
  # Disable quiet mode to ensure OK count is printed
  __CLI_QUIET="false"
  UI_LANG="en"

  # Parameters: ok=5, fail=0, missing=0, skip=2, bad_sig=0, signed=0, bad_lines=0
  run ui::log_report_summary 5 0 0 2 0 0 0

  assert_success

  # Should print OK summary
  assert_output --partial "5"
  assert_output --partial "$(ui::get_msg 'rpt_verify')"

  # Should print SKIPPED summary (plural)
  assert_output --partial "2"
  assert_output --partial "$(ui::get_msg 'rpt_skip_pl')"

  # Should NOT print FAILED or MISSING strings
  refute_output --partial "$(ui::get_msg 'rpt_fail_sg')"
  refute_output --partial "$(ui::get_msg 'rpt_fail_pl')"
  refute_output --partial "$(ui::get_msg 'rpt_miss_sg')"
}

@test "UI: log_report_summary handles singular vs plural messages" {
  __CLI_QUIET="false"
  UI_LANG="en"

  # Parameters: ok=1, fail=1, missing=0, skip=0, bad_sig=0, signed=0, bad_lines=0
  run ui::log_report_summary 1 1 0 0 0 0 0

  assert_success

  # Should print singular FAILED
  assert_output --partial "1"
  assert_output --partial "$(ui::get_msg 'rpt_fail_sg')"

  # Should NOT print plural FAILED
  refute_output --partial "$(ui::get_msg 'rpt_fail_pl')"
}

@test "UI: log_report_summary respects quiet mode for OK counts" {
  # Enable quiet mode
  __CLI_QUIET="true"
  UI_LANG="en"

  # Parameters: ok=5, fail=1, missing=0, skip=0, bad_sig=0, signed=0, bad_lines=0
  run ui::log_report_summary 5 1 0 0 0 0 0

  assert_success

  # Should print FAILED
  assert_output --partial "$(ui::get_msg 'rpt_fail_sg')"

  # Should NOT print OK verify message due to quiet mode
  refute_output --partial "$(ui::get_msg 'rpt_verify')"
}
