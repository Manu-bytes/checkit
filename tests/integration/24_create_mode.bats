#!/usr/bin/env bats
#
# tests/integration/24_create_mode.bats
# Integration Test: Create Mode & Output Formats
#
# Responsibility: Validate the creation of checksums/manifests, including
# format variations (GNU, BSD, JSON) and GPG signing integration.

load '../test_helper'

setup() {
  load_lib "constants.sh"

  # 1. Sandbox Setup
  TEST_DIR="$(mktemp -d "${BATS_TMPDIR}/checkit_create_mode_XXXXXX")"
  TEST_FILE="${TEST_DIR}/data.txt"
  touch "$TEST_FILE"

  # 2. Setup Mocks
  MOCK_BIN_DIR="${TEST_DIR}/bin"
  mkdir -p "$MOCK_BIN_DIR"

  # Define a fixed hash for predictability
  FULL_HASH="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

  # Mock Hasher (Simulates sha256sum, etc.)
  # It ignores the input file content and outputs our fixed hash + filename
  cat <<EOF >"$MOCK_BIN_DIR/hasher_mock"
#!/bin/bash
# Get the last argument (filename)
FILE="\${@: -1}"
# Output standard GNU format
echo "$FULL_HASH  \$FILE"
exit 0
EOF
  chmod +x "$MOCK_BIN_DIR/hasher_mock"

  # Alias all potential hashers to this mock
  cp "$MOCK_BIN_DIR/hasher_mock" "$MOCK_BIN_DIR/sha256sum"
  cp "$MOCK_BIN_DIR/hasher_mock" "$MOCK_BIN_DIR/sha384sum"
  cp "$MOCK_BIN_DIR/hasher_mock" "$MOCK_BIN_DIR/shasum"

  # Mock GPG (Simulates Clearsign)
  cat <<EOF >"$MOCK_BIN_DIR/gpg"
#!/bin/bash
if [[ "\$1" == "--clearsign" ]]; then
  input=\$(cat) # Read stdin
  echo "-----BEGIN PGP SIGNED MESSAGE-----"
  echo "Hash: SHA512"
  echo ""
  echo "\$input"
  echo "-----BEGIN PGP SIGNATURE-----"
  echo "mock_signature_block"
  exit 0
fi
exit 1
EOF
  chmod +x "$MOCK_BIN_DIR/gpg"

  export PATH="$MOCK_BIN_DIR:$PATH"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "Create: Default output is GNU format" {
  run "$CHECKIT_EXEC" "$TEST_FILE"

  assert_success
  # Expect: HASH  FILENAME
  assert_output --partial "$FULL_HASH  $TEST_FILE"
}

@test "Create: --tag produces BSD format" {
  run "$CHECKIT_EXEC" --tag "$TEST_FILE"

  assert_success
  # Expect: SHA256 (FILENAME) = HASH
  assert_output "SHA256 ($TEST_FILE) = $FULL_HASH"
}

@test "Create: --format json produces valid JSON structure" {
  run "$CHECKIT_EXEC" --format json "$TEST_FILE"

  assert_success
  assert_output --partial '"algorithm": "SHA256"'
  assert_output --partial "\"hash\": \"$FULL_HASH\""
  assert_output --partial "\"filename\": \"$TEST_FILE\""
}

@test "Create: --sign injects 'Content-Hash' header for GNU format" {
  # This tests the "Smart Header" feature where we declare the hash algo inside the GPG wrapper
  run "$CHECKIT_EXEC" "$TEST_FILE" --algo sha384 --sign

  assert_success

  # 1. Check for GPG Armor
  assert_output --partial "-----BEGIN PGP SIGNED MESSAGE-----"

  # 2. Check for Custom Header injection
  # (This helps checkit identify the algo later without guessing)
  assert_output --partial "Content-Hash: SHA384"

  # 3. Check for Content
  assert_output --partial "$FULL_HASH  $TEST_FILE"
}

@test "Create: --sign DOES NOT inject 'Content-Hash' for BSD/JSON" {
  # BSD/JSON formats are self-describing or strictly formatted,
  # so injecting a header into the text body might break parsing or be redundant.

  run "$CHECKIT_EXEC" "$TEST_FILE" --tag --sign

  assert_success
  refute_output --partial "Content-Hash:"
  assert_output --partial "SHA256 ($TEST_FILE)"
}

@test "Create: --sign DOES NOT inject 'Content-Hash' for --all mode" {
  # When generating ALL hashes, a single Content-Hash header is ambiguous/wrong.
  run "$CHECKIT_EXEC" "$TEST_FILE" --all --sign

  assert_success
  refute_output --partial "Content-Hash:"
}
