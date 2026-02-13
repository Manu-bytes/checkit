#!/usr/bin/env bats
#
# tests/integration/22_verify_string_ambiguity.bats
# Integration Test: Verify String Mode Ambiguity
#
# Responsibility: Verify fallback logic when providing "File + HashString" arguments.
# Specifically, 40 chars could be SHA-1 or BLAKE2-160.

load '../test_helper'

setup() {
  load_lib "constants.sh"

  # 1. Sandbox Setup
  TEST_DIR="$(mktemp -d "${BATS_TMPDIR}/checkit_ambiguity_string_XXXXXX")"
  TEST_FILE="${TEST_DIR}/debian.iso"
  touch "$TEST_FILE"

  # 40-char Hash
  HASH_40=$(printf 'a%.0s' {1..40})

  # 2. Setup Mocks
  MOCK_BIN_DIR="${TEST_DIR}/bin"
  mkdir -p "$MOCK_BIN_DIR"

  # --- MOCK SHA1SUM ---
  # Simulate FAILURE (Collision scenario: SHA-1 is tried first but fails)
  cat <<EOF >"$MOCK_BIN_DIR/sha1sum"
#!/bin/bash
exit 1
EOF

  # --- MOCK B2SUM ---
  # Simulate SUCCESS.
  # Important: In verify string mode, checkit CALCULATES the hash.
  # So this mock must output the hash matching HASH_40.
  cat <<EOF >"$MOCK_BIN_DIR/b2sum"
#!/bin/bash
# Logic: If called with length 160 (-l 160), output our hash
if [[ "\$*" == *"-l 160"* ]]; then
  echo "$HASH_40  \$1"
  exit 0
fi
exit 1
EOF

  chmod +x "$MOCK_BIN_DIR/sha1sum" "$MOCK_BIN_DIR/b2sum"
  # Symlink sha1sum to shasum just in case
  cp "$MOCK_BIN_DIR/sha1sum" "$MOCK_BIN_DIR/shasum"

  export PATH="$MOCK_BIN_DIR:$PATH"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "Verify String: Falls back to BLAKE2-160 if SHA-1 fails (Ambiguity Resolution)" {
  # Logic: Checkit sees 40 chars. Tries SHA-1. Mock fails.
  # Falls back to BLAKE2-160. Mock calculates hash. Matches input. Success.

  run "$CHECKIT_EXEC" "$TEST_FILE" "$HASH_40"

  assert_success

  # Verify correct algorithm reporting
  assert_output --partial "[OK]"
  assert_output --partial "(blake2-160)"
}

@test "Verify String: Respects --algo flag overriding auto-detection" {
  # Logic: User forces blake2-160. SHA-1 should not even be tried.

  run "$CHECKIT_EXEC" --algo blake2-160 "$TEST_FILE" "$HASH_40"

  assert_success
  assert_output --partial "[OK]"
  assert_output --partial "(blake2-160)"
}
