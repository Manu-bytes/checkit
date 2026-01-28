#!/usr/bin/env bats

# shellcheck disable=SC2329
load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"
  source "$PROJECT_ROOT/lib/utils/clipboard.sh"
}

@test "Utils: copy_to_clipboard fails gracefully if no tool found" {
  # We force an empty PATH so that it does not find any tools.
  # (We save the original PATH so as not to break bats.)
  local OLD_PATH=$PATH
  export PATH="/tmp/empty"

  run utils::copy_to_clipboard "secret_hash"

  export PATH=$OLD_PATH

  assert_failure "$EX_OPERATIONAL_ERROR"
}

@test "Utils: copy_to_clipboard uses pbcopy if available (MacOS style)" {
  # Mock pbcopy
  function pbcopy() {
    # We read from stdin
    cat >/tmp/pbcopy_mock
    return 0
  }
  export -f pbcopy

  run utils::copy_to_clipboard "hash_mac"

  assert_success
  run cat /tmp/pbcopy_mock
  assert_output "hash_mac"
}

@test "Utils: copy_to_clipboard uses xclip if available (Linux style)" {
  # Mock xclip
  # xclip -selection clipboard usually
  function xclip() {
    cat >/tmp/xclip_mock
    return 0
  }
  export -f xclip

  # We simulate that pbcopy does not exist, but xclip does.
  function type() {
    if [[ "$1" == "xclip" ]]; then return 0; fi
    return 1
  }

  export -f type

  run utils::copy_to_clipboard "hash_linux"

  assert_success
  run cat /tmp/xclip_mock
  assert_output "hash_linux"
}

@test "Utils: copy_to_clipboard uses wl-copy if available (Wayland style)" {
  # 1. Mock wl-copy
  function wl-copy() {
    cat >/tmp/wl_mock
    return 0
  }
  export -f wl-copy

  # 2. Mock ‘type’ to simulate that ONLY wl-copy exists.
  # This is crucial because the function checks pbcopy first.
  function type() {
    local tool="$1"
    if [[ "$tool" == "wl-copy" ]]; then return 0; fi
    return 1
  }
  export -f type

  # 3. Execution
  run utils::copy_to_clipboard "hash_wayland"

  assert_success
  run cat /tmp/wl_mock
  assert_output "hash_wayland"
}
