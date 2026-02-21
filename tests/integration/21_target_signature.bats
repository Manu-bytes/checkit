#!/usr/bin/env bats
#
# tests/integration/21_target_signature.bats
# Integration Test: Target File Signature Detection
#
# Responsibility: Verify that checkit detects detached signatures for the
# target data files themselves (e.g., iso.sig next to iso) and reports
# them in the status output.

load '../test_helper'

setup() {
  load_lib "constants.sh"

  # 1. Sandbox Setup
  TEST_DIR="$(mktemp -d "${BATS_TMPDIR}/checkit_sig_target_XXXXXX")"
  DATA_FILE="${TEST_DIR}/image.iso"
  touch "$DATA_FILE"
  # Create the detached signature file
  touch "${DATA_FILE}.sig"

  # 2. Setup Checksum File
  # We use a 64-char hash (SHA-256)
  VALID_HASH=$(printf 'a%.0s' {1..64})
  SUMFILE="${TEST_DIR}/checksums.txt"
  echo "$VALID_HASH  $DATA_FILE" >"$SUMFILE"

  # 3. Setup Mocks
  MOCK_BIN_DIR="${TEST_DIR}/bin"
  mkdir -p "$MOCK_BIN_DIR"

  # --- MOCK GPG ---
  # Returns success if asked to verify image.iso.sig
  cat <<EOF >"$MOCK_BIN_DIR/gpg"
#!/bin/bash
ARGS="\$*"
if [[ "\$ARGS" == *"image.iso.sig"* ]]; then
  echo "gpg: Good signature from \"Arch Linux\"" >&2
  exit 0
fi
exit 1
EOF

  # --- MOCK SHA256SUM ---
  # Critical: We must ensure the hash check passes too!
  cat <<EOF >"$MOCK_BIN_DIR/sha256sum"
#!/bin/bash
# If verifying (-c), return success
if [[ "\$*" == *"-c"* ]]; then exit 0; fi
# If calculating, return the valid hash
echo "$VALID_HASH  \$1"
EOF

  chmod +x "$MOCK_BIN_DIR/gpg" "$MOCK_BIN_DIR/sha256sum"
  cp "$MOCK_BIN_DIR/sha256sum" "$MOCK_BIN_DIR/shasum"

  export PATH="$MOCK_BIN_DIR:$PATH"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "Target Sig: Detects and verifies signature of the target file itself" {
  run "$CHECKIT_EXEC" -c "$SUMFILE"

  assert_success

  # 1. Verify Hash Status
  assert_output --partial "[OK]"
  assert_output --partial "image.iso"

  # 2. Verify Signature Status (The core goal of this test)
  # Checkit should append [SIGNED] or similar indicator when a target sig is found
  assert_output --partial "[SIGNED]"
}
