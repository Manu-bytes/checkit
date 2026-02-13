#!/usr/bin/env bats
#
# tests/integration/20_security_gpg.bats
# Integration Test: GPG Security Enforcement
#
# Responsibility: Validate that GPG signatures are correctly detected and
# verified. Ensure that --verify-sign enforces strict security policies
# (Fail Hard) while default mode only warns the user.

load '../test_helper'

setup() {
  load_lib "constants.sh"

  # 1. Sandbox Setup
  TEST_DIR="$(mktemp -d "${BATS_TMPDIR}/checkit_gpg_XXXXXX")"
  DATA_FILE="${TEST_DIR}/distro.iso"
  touch "$DATA_FILE"

  VALID_HASH=$(printf 'a%.0s' {1..64})

  # 2. Mock GPG Setup
  MOCK_BIN_DIR="${TEST_DIR}/bin"
  mkdir -p "$MOCK_BIN_DIR"

  # Custom GPG Mock: Simulates different verification results based on filename
  cat <<EOF >"$MOCK_BIN_DIR/gpg"
#!/bin/bash
ARGS="\$*"

if [[ "\$ARGS" == *"good.asc"* ]] || [[ "\$ARGS" == *"plain.txt.sig"* ]]; then
  echo "gpg: Good signature from \"Trusted Signer\"" >&2
  exit 0
fi

if [[ "\$ARGS" == *"bad.asc"* ]]; then
  echo "gpg: BAD signature from \"Evil Hacker\"" >&2
  exit 1
fi

if [[ "\$ARGS" == *"missing.asc"* ]]; then
  echo "gpg: Can't check signature: No public key" >&2
  exit 2
fi

exit 1
EOF

  # 3.Mock sha256sum
  cat <<EOF >"$MOCK_BIN_DIR/sha256sum"
#!/bin/bash
if [[ "\$*" == *"-c"* ]]; then
  exit 0
fi
echo "$VALID_HASH  \$1"
EOF
  chmod +x "$MOCK_BIN_DIR/gpg" "$MOCK_BIN_DIR/sha256sum"
  cp "$MOCK_BIN_DIR/sha256sum" "$MOCK_BIN_DIR/shasum"

  # 4. Create Signed Test Files

  # A. Inline Signed Files
  GOOD_ASC="${TEST_DIR}/good.asc"
  BAD_ASC="${TEST_DIR}/bad.asc"
  MISSING_ASC="${TEST_DIR}/missing.asc"

  create_inline_signed() {
    echo "-----BEGIN PGP SIGNED MESSAGE-----"
    echo "Hash: SHA256"
    echo ""
    echo "$VALID_HASH  $DATA_FILE"
  }

  create_inline_signed >"$GOOD_ASC"
  create_inline_signed >"$BAD_ASC"
  create_inline_signed >"$MISSING_ASC"

  # B. Detached Signature Setup
  PLAIN_TXT="${TEST_DIR}/plain.txt"
  PLAIN_SIG="${TEST_DIR}/plain.txt.sig"
  echo "$VALID_HASH  $DATA_FILE" >"$PLAIN_TXT"
  touch "$PLAIN_SIG"

  # 5. Inject Mock PATH
  export PATH="$MOCK_BIN_DIR:$PATH"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# --- Test Cases ---

@test "Security: Strict Mode passes on VALID signature (Inline)" {
  run "$CHECKIT_EXEC" -c "$GOOD_ASC" --verify-sign

  assert_success
  assert_output --partial "Good signature found" # signature verified
  assert_output --partial "OK"
}

@test "Security: Strict Mode FAILS HARD on BAD signature" {
  run "$CHECKIT_EXEC" -c "$BAD_ASC" --verify-sign

  assert_failure "$EX_SECURITY_FAIL"
  assert_output --partial "CRITICAL"
  assert_output --partial "BAD signature detected"
}

@test "Security: Strict Mode FAILS on MISSING public key" {
  run "$CHECKIT_EXEC" -c "$MISSING_ASC" --verify-sign

  assert_failure "$EX_SECURITY_FAIL"
  assert_output --partial "ERROR"
  assert_output --partial "key missing"
}

@test "Security: Detached Signature is automatically detected and verified" {
  # Logic: checkit sees 'plain.txt.sig' when checking 'plain.txt'
  run "$CHECKIT_EXEC" -c "$PLAIN_TXT" --verify-sign

  assert_success
  assert_output --partial "Good signature found"
  assert_output --partial "OK"
}

@test "Security: Auto Mode WARNS (but proceeds) on BAD signature" {
  # Default behavior: Warning only, does not stop execution
  run "$CHECKIT_EXEC" -c "$BAD_ASC"

  assert_success
  assert_output --partial "WARNING"
  assert_output --partial "BAD signature detected"
  # Should still process the hash
  assert_output --partial "OK"
}
