#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"

  # Create mock bin directory
  MOCK_BIN_DIR="$BATS_TMPDIR/checkit_mocks_gpg"
  mkdir -p "$MOCK_BIN_DIR"
  export PATH="$MOCK_BIN_DIR:$PATH"

  # --- GPG MOCK ---
  # Simulates GPG exit codes and stderr output based on input filename.
  # logic is simplified to substring matching to avoid argument count collisions.
  cat <<EOF >"$MOCK_BIN_DIR/gpg"
#!/bin/bash

# Join all arguments into a single string for pattern matching
ARGS="\$*"

# Case 1: Detached Signature (Ubuntu style)
# checkit calls: gpg --verify plain.txt.sig plain.txt
if [[ "\$ARGS" == *"plain.txt.sig"* ]]; then
  echo "gpg: Good signature from \"Detached Signer\"" >&2
  exit 0
fi

# Case 2: Inline Signature (Fedora style)
# checkit calls: gpg --verify good.asc
if [[ "\$ARGS" == *"good.asc"* ]]; then
  echo "gpg: Good signature from \"Fedora Project\"" >&2
  exit 0
fi

# Case 3: Bad Signature
if [[ "\$ARGS" == *"bad.asc"* ]]; then
  echo "gpg: BAD signature from \"Evil Hacker\"" >&2
  exit 1
fi

# Case 4: Missing Public Key
if [[ "\$ARGS" == *"missing.asc"* ]]; then
  echo "gpg: Can't check signature: No public key" >&2
  exit 2
fi

# Default fallback
exit 1
EOF
  chmod +x "$MOCK_BIN_DIR/gpg"

  # --- SHA256SUM MOCK ---
  # Always returns success to isolate GPG logic testing
  cat <<EOF >"$MOCK_BIN_DIR/sha256sum"
#!/bin/bash
exit 0
EOF
  chmod +x "$MOCK_BIN_DIR/sha256sum"

  # --- TEST DATA CREATION ---
  DATA_FILE="distro.iso"
  touch "$DATA_FILE"

  VALID_HASH=$(printf 'a%.0s' {1..64})

  # 1. Inline Signed File (Standard PGP header required for detection)
  {
    echo "-----BEGIN PGP SIGNED MESSAGE-----"
    echo "Hash: SHA256"
    echo ""
    echo "$VALID_HASH $DATA_FILE"
  } >>"good.asc"

  # Clone for failure scenarios
  cp "good.asc" "bad.asc"
  cp "good.asc" "missing.asc"

  # 2. Detached Signature Files
  # plain.txt has NO PGP header
  echo "$VALID_HASH $DATA_FILE" >"plain.txt"
  # plain.txt.sig exists to be auto-detected by gpg::detect_signature
  touch "plain.txt.sig"
}

teardown() {
  rm -rf "$MOCK_BIN_DIR"
  rm -f "good.asc" "bad.asc" "missing.asc" "plain.txt" "plain.txt.sig" "$DATA_FILE"
}

# --- TEST CASES ---

@test "Security: Strict Mode passes on VALID signature (Inline)" {
  run "$CHECKIT_EXEC" -c "good.asc" --verify-sign

  assert_success
  assert_output --partial "Signature Verified"
}

@test "Security: Strict Mode FAILS HARD on BAD signature" {
  run "$CHECKIT_EXEC" -c "bad.asc" --verify-sign

  assert_failure "$EX_SECURITY_FAIL"
  assert_output --partial "BAD signature"
}

@test "Security: Strict Mode FAILS on MISSING public key" {
  run "$CHECKIT_EXEC" -c "missing.asc" --verify-sign

  assert_failure "$EX_SECURITY_FAIL"
  assert_output --partial "Public key missing"
}

@test "Security: Detached Signature is automatically detected and verified" {
  # Logic: checkit should detect 'plain.txt.sig' automatically when checking 'plain.txt'
  run "$CHECKIT_EXEC" -c "plain.txt" --verify-sign

  assert_success
  assert_output --partial "Signature Verified"
}

@test "Security: Auto Mode WARNS (but proceeds) on BAD signature" {
  # Without --verify-sign, execution continues but warns user
  run "$CHECKIT_EXEC" -c "bad.asc"

  assert_success
  assert_output --partial "[WARNING]"
  assert_output --partial "BAD signature"
}
