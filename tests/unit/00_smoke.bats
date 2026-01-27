#!/usr/bin/env bats

load '../test_helper'

@test "Smoke: The test environment loads correctly." {
  run true
  assert_success
}

@test "Smoke: The checkit executable exists and is executable." {
  run test -x "$CHECKIT_EXEC"
  assert_success
}

@test "Smoke: checkit can be invoked" {
  run "$CHECKIT_EXEC" || true

  # Accept absolute success
  if [ "$status" -eq 0 ]; then
    return 0
  fi

  # Accept common usage/arguments exit code
  if [ "$status" -eq 2 ]; then
    return 0
  fi

  # Accept if output contains help/usage text
  if echo "$output" | grep -qiE 'usage|help|--help|-h'; then
    return 0
  fi

  fail "Executable failed to run properly: exit=$status output=$(echo "$output" | tr '\n' ' ')"
}
