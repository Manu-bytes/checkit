#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"

  DATA_FILE="image.iso"
  touch "$DATA_FILE"
  touch "${DATA_FILE}.sig"

  VALID_HASH=$(printf 'a%.0s' {1..64})

  SUMFILE="checksums.txt"
  echo "$VALID_HASH  $DATA_FILE" >"$SUMFILE"

  MOCK_BIN_DIR="$BATS_TMPDIR/checkit_mocks_target_sig"
  LOG_FILE="$BATS_TMPDIR/sig_test_calls.log"
  rm -f "$LOG_FILE"

  setup_integration_mocks "$MOCK_BIN_DIR" "$LOG_FILE"
  export PATH="$MOCK_BIN_DIR:$PATH"

  # --- MOCK GPG ---
  cat <<EOF >"$MOCK_BIN_DIR/gpg"
#!/bin/bash
ARGS="\$*"

# Case: ISO image signing (target file)
if [[ "\$ARGS" == *"image.iso.sig"* ]]; then
  echo "gpg: Good signature from \"Arch Linux\"" >&2
  exit 0
fi

# Default fail
exit 1
EOF
  chmod +x "$MOCK_BIN_DIR/gpg"
}

teardown() {
  rm -rf "$MOCK_BIN_DIR"
  rm -f "$DATA_FILE" "${DATA_FILE}.sig" "$SUMFILE"
}

@test "Target Sig: Detects and verifies signature of the target file itself" {
  run "$CHECKIT_EXEC" -c "$SUMFILE"
  assert_success

  assert_output --partial "[OK] $DATA_FILE"
  assert_output --partial "[SIGNED]"
}
