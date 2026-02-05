#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"

  TEST_FILE="data.txt"
  touch "$TEST_FILE"

  MOCK_BIN_DIR="$BATS_TMPDIR/checkit_mocks_create"
  mkdir -p "$MOCK_BIN_DIR"

  FULL_HASH="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

  # Hash generation
  cat <<EOF >"$MOCK_BIN_DIR/hasher_mock"
#!/bin/bash
FILE="\${@: -1}"
echo "$FULL_HASH  \$FILE"
exit 0
EOF
  chmod +x "$MOCK_BIN_DIR/hasher_mock"

  cp "$MOCK_BIN_DIR/hasher_mock" "$MOCK_BIN_DIR/sha256sum"
  cp "$MOCK_BIN_DIR/hasher_mock" "$MOCK_BIN_DIR/sha384sum"
  cp "$MOCK_BIN_DIR/hasher_mock" "$MOCK_BIN_DIR/shasum"

  # --- MOCK GPG ---
  cat <<EOF >"$MOCK_BIN_DIR/gpg"
#!/bin/bash
if [[ "\$1" == "--clearsign" ]]; then
  input=\$(cat)

  echo "-----BEGIN PGP SIGNED MESSAGE-----"
  echo "Hash: SHA512"
  echo ""
  echo "\$input"
  echo "-----BEGIN PGP SIGNATURE-----"
  exit 0
fi
exit 1
EOF
  chmod +x "$MOCK_BIN_DIR/gpg"

  export PATH="$MOCK_BIN_DIR:$PATH"
}

teardown() {
  rm -rf "$MOCK_BIN_DIR"
  rm -f "$TEST_FILE"
}

@test "Create: Default output is GNU format" {
  run "$CHECKIT_EXEC" "$TEST_FILE"
  assert_success
  assert_output --partial "$FULL_HASH  data.txt"
}

@test "Create: --tag produces BSD format" {
  run "$CHECKIT_EXEC" --tag "$TEST_FILE"
  assert_success
  assert_output "SHA256 ($TEST_FILE) = $FULL_HASH"
}

@test "Create: --output json produces valid JSON structure" {
  run "$CHECKIT_EXEC" --output json "$TEST_FILE"
  assert_success
  assert_output --partial '"algorithm": "sha256"'
  assert_output --partial "\"hash\": \"$FULL_HASH\""
}

@test "Create: --sign injects 'Content-Hash' header for GNU format" {
  # Case: GNU format (default) + sha384
  run "$CHECKIT_EXEC" "$TEST_FILE" --algo sha384 --sign

  assert_success

  assert_output --partial "-----BEGIN PGP SIGNED MESSAGE-----"

  assert_output --partial "Hash: SHA512"

  assert_output --partial "Content-Hash: sha384"

  assert_output --partial "$FULL_HASH  data.txt"
}

@test "Create: --sign DOES NOT inject 'Content-Hash' for BSD/JSON" {
  run "$CHECKIT_EXEC" "$TEST_FILE" --tag --sign

  assert_success
  refute_output --partial "Content-Hash:"
  assert_output --partial "SHA256 ($TEST_FILE)"
}

@test "Create: --sign DOES NOT inject 'Content-Hash' for --all mode" {
  run "$CHECKIT_EXEC" "$TEST_FILE" --all --sign

  assert_success
  refute_output --partial "Content-Hash:"
}
