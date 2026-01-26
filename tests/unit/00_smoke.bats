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

@test "Smoke: checkit can be invoked (even if it is empty)" {
  run "$CHECKIT_EXEC"
  assert_success
}
