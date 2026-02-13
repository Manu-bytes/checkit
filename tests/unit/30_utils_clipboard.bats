#!/usr/bin/env bats
#
# tests/unit/30_utils_clipboard.bats
# Clipboard Utility Unit Tests.
#
# Responsibility: Verify the detection and execution priority of clipboard tools
# (pbcopy, wl-copy, xclip, xsel).

load '../test_helper'

setup() {
  load_lib "constants.sh"
  load_lib "utils/clipboard.sh"

  # Define a temporary output file for verifying mocks
  MOCK_OUTPUT="${BATS_TMPDIR}/clipboard_mock_$$"
}

teardown() {
  rm -f "$MOCK_OUTPUT"
}

# --- Helper: Command Mocker ---
# This function overrides the builtin 'command' to simulate the presence
# or absence of specific tools regardless of the host OS.
#
# $1 - target_tool - The tool that should "exist" (return 0).
#                    All other tools will "not exist" (return 1).
mock_command_v() {
  local target="$1"

  # We export the function so it is visible inside the 'run' subshell
  # shellcheck disable=SC2016
  eval "
    function command() {
      if [[ \"\$1\" == \"-v\" ]]; then
        if [[ \"\$2\" == \"$target\" ]]; then return 0; fi
        return 1
      fi
      builtin command \"\$@\"
    }
    export -f command
  "
}

# --- Tests ---

@test "Utils: copy_to_clipboard fails gracefully if no tool found" {
  # Mock 'command -v' to return failure for ALL tools
  mock_command_v "non_existent_tool"

  run utils::copy_to_clipboard "secret_hash"

  assert_failure "$EX_OPERATIONAL_ERROR"
}

@test "Utils: copy_to_clipboard prioritizes pbcopy (MacOS)" {
  # 1. Simulate that ONLY pbcopy exists
  mock_command_v "pbcopy"

  # 2. Mock the actual execution of pbcopy
  function pbcopy() {
    cat >"$MOCK_OUTPUT"
  }
  export -f pbcopy

  # 3. Execution
  run utils::copy_to_clipboard "hash_mac_value"

  assert_success
  run cat "$MOCK_OUTPUT"
  assert_output "hash_mac_value"
}

@test "Utils: copy_to_clipboard prioritizes wl-copy (Wayland) if pbcopy missing" {
  # 1. Simulate that wl-copy exists (pbcopy implies missing by logic)
  mock_command_v "wl-copy"

  # 2. Mock execution
  function wl-copy() {
    cat >"$MOCK_OUTPUT"
  }
  export -f wl-copy

  run utils::copy_to_clipboard "hash_wayland_value"

  assert_success
  run cat "$MOCK_OUTPUT"
  assert_output "hash_wayland_value"
}

@test "Utils: copy_to_clipboard falls back to xclip (X11)" {
  # 1. Simulate that xclip exists
  mock_command_v "xclip"

  # 2. Mock execution (handles args like -selection clipboard)
  function xclip() {
    cat >"$MOCK_OUTPUT"
  }
  export -f xclip

  run utils::copy_to_clipboard "hash_x11_value"

  assert_success
  run cat "$MOCK_OUTPUT"
  assert_output "hash_x11_value"
}

@test "Utils: copy_to_clipboard falls back to xsel (X11 Legacy)" {
  # 1. Simulate that xsel exists
  mock_command_v "xsel"

  # 2. Mock execution
  function xsel() {
    cat >"$MOCK_OUTPUT"
  }
  export -f xsel

  run utils::copy_to_clipboard "hash_xsel_value"

  assert_success
  run cat "$MOCK_OUTPUT"
  assert_output "hash_xsel_value"
}
