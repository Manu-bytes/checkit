#!/usr/bin/env bats
#
# tests/unit/21_adapters_gpg.bats
# GPG Adapter Unit Tests.
#
# Responsibility: Verify that GPG status output is parsed correctly and
# mapped to internal exit codes (EX_SUCCESS, EX_SECURITY_FAIL, etc.).
# shellcheck disable=SC2329

load '../test_helper'

setup() {
  load_lib "constants.sh"
  load_lib "adapters/gpg.sh"

  # Create dummy files for testing
  touch "${BATS_TMPDIR}/signed_file.txt"
  TEST_FILE="${BATS_TMPDIR}/signed_file.txt"

  # --- MOCK GPG ---
  gpg() {
    # Logic based on global variable set in test
    if [[ "$GPG_MOCK_STATUS" == "GOOD" ]]; then
      return 0
    elif [[ "$GPG_MOCK_STATUS" == "BAD" ]]; then
      echo "gpg: BAD signature from..."
      return 1
    elif [[ "$GPG_MOCK_STATUS" == "NOKEY" ]]; then
      echo "gpg: Can't check signature: No public key"
      return 2
    else
      echo "gpg: Unknown error"
      return 1
    fi
  }
  export -f gpg
}

teardown() {
  rm -f "$TEST_FILE"
}

# --- Detection Logic ---

@test "Adapter: gpg::detect_signature finds inline header" {
  echo "-----BEGIN PGP SIGNED MESSAGE-----" >"$TEST_FILE"
  run gpg::detect_signature "$TEST_FILE"
  assert_success
}

@test "Adapter: gpg::detect_signature finds detached .asc file" {
  touch "${TEST_FILE}.asc"

  # We empty the file content to ensure it doesn't match inline header
  echo "just data" >"$TEST_FILE"

  run gpg::detect_signature "$TEST_FILE"
  assert_success

  rm "${TEST_FILE}.asc"
}

# --- Verification Logic ---

@test "Adapter: gpg::verify returns EX_SUCCESS on good signature" {
  export GPG_MOCK_STATUS="GOOD"

  run gpg::verify "$TEST_FILE"
  assert_success
}

@test "Adapter: gpg::verify returns EX_SECURITY_FAIL on BAD signature" {
  export GPG_MOCK_STATUS="BAD"

  run gpg::verify "$TEST_FILE"
  assert_failure "$EX_SECURITY_FAIL"
  assert_output --partial "BAD signature"
}

@test "Adapter: gpg::verify returns EX_OPERATIONAL_ERROR on missing key" {
  export GPG_MOCK_STATUS="NOKEY"

  run gpg::verify "$TEST_FILE"
  assert_failure "$EX_OPERATIONAL_ERROR"
  assert_output --partial "No public key"
}

# --- Detached Signature Discovery ---

@test "Adapter: gpg::find_detached_sig locates .asc extension" {
  touch "${TEST_FILE}.asc"
  run gpg::find_detached_sig "$TEST_FILE"
  assert_success
  assert_output "${TEST_FILE}.asc"
  rm -f "${TEST_FILE}.asc"
}

@test "Adapter: gpg::find_detached_sig returns error if no signature exists" {
  run gpg::find_detached_sig "$TEST_FILE"
  assert_failure
}

# --- Detached Verification Logic ---

@test "Adapter: gpg::verify_detached returns EX_SUCCESS on good signature" {
  touch "${TEST_FILE}.asc"
  export GPG_MOCK_STATUS="GOOD"

  run gpg::verify_detached "$TEST_FILE"
  assert_success
  rm -f "${TEST_FILE}.asc"
}

@test "Adapter: gpg::verify_detached returns EX_SECURITY_FAIL on BAD signature" {
  touch "${TEST_FILE}.asc"
  export GPG_MOCK_STATUS="BAD"

  run gpg::verify_detached "$TEST_FILE"
  assert_failure "$EX_SECURITY_FAIL"
  assert_output --partial "BAD signature"
  rm -f "${TEST_FILE}.asc"
}

@test "Adapter: gpg::verify_detached fails if signature file is missing" {
  # Ensure no .asc, .sig, or .gpg file exists for TEST_FILE
  run gpg::verify_detached "$TEST_FILE"
  assert_failure "$EX_OPERATIONAL_ERROR"
}

# --- Signing Logic ---

@test "Adapter: gpg::sign_data uses clearsign by default" {
  # Override mock locally to output received arguments
  gpg() {
    echo "$@"
    return 0
  }
  export -f gpg

  run gpg::sign_data "dummy_content" "" "false"
  assert_success
  assert_output --partial "--clearsign"
}

@test "Adapter: gpg::sign_data applies detach and armor flags" {
  gpg() {
    echo "$@"
    return 0
  }
  export -f gpg

  run gpg::sign_data "dummy_content" "detach" "true"
  assert_success
  assert_output --partial "--detach-sign"
  assert_output --partial "--armor"
}

@test "Adapter: gpg::sign_file executes detached file signing" {
  gpg() {
    echo "$@"
    return 0
  }
  export -f gpg

  run gpg::sign_file "$TEST_FILE" "true"
  assert_success
  assert_output --partial "--detach-sign"
  assert_output --partial "--armor"
  assert_output --partial "$TEST_FILE"
}
