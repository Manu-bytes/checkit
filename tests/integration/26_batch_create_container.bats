#!/usr/bin/env bats
#
# tests/integration/26_batch_create_container.bats
# Integration Test: Batch Creation (Container Mode)
#
# Responsibility: Validate that multiple input files result in a single,
# aggregated output file (manifest/container), correctly formatted and signed.

load '../test_helper'

setup() {
  load_lib "constants.sh"

  # 1. Sandbox Setup
  TEST_DIR="$(mktemp -d "${BATS_TMPDIR}/checkit_batch_XXXXXX")"

  # 2. Create Dummy "ISO" files
  touch "${TEST_DIR}/archlinux-release.iso"
  touch "${TEST_DIR}/archlinux-stable.iso"
  touch "${TEST_DIR}/archlinux-kernel.iso"

  # 3. Setup Mocks
  MOCK_BIN_DIR="${TEST_DIR}/bin"
  mkdir -p "$MOCK_BIN_DIR"

  # Mock Hasher: Returns a fake hash based on the filename length to be distinct
  cat <<EOF >"$MOCK_BIN_DIR/sha256sum"
#!/bin/bash
# Returns: <FAKE_HASH>  <FILENAME>
# We assume the file is the last argument
FILE="\${@: -1}"
echo "a1b2c3d4e5f6g7h8i9j0_mock_hash_for_\$(basename "\$FILE")  \$FILE"
exit 0
EOF
  chmod +x "$MOCK_BIN_DIR/sha256sum"

  # Mock GPG: Wraps input in PGP Armor
  cat <<EOF >"$MOCK_BIN_DIR/gpg"
#!/bin/bash
# Logic: If --clearsign is passed, wrap stdin
if [[ "\$1" == "--clearsign" ]]; then
  echo "-----BEGIN PGP SIGNED MESSAGE-----"
  echo "Hash: SHA256"
  echo ""
  cat - # Read stdin
  echo ""
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

@test "Batch: Creates a single GNU container file for multiple inputs" {
  local output_file="${TEST_DIR}/SHA256SUMS"

  # Execution: Pass all ISOs using a glob pattern (expanded by bash before checkit sees it)
  # syntax: checkit file1 file2 file3 --output-file ...
  run "$CHECKIT_EXEC" "${TEST_DIR}/"*.iso -o "$output_file"

  assert_success

  # 1. Verify Output File Exists
  [ -f "$output_file" ] || fail "Output container file not created"

  # 2. Verify Content (Should contain 3 lines, one per file)
  run cat "$output_file"
  assert_output --partial "archlinux-release.iso"
  assert_output --partial "archlinux-stable.iso"
  assert_output --partial "archlinux-kernel.iso"

  # Check line count (should be 3 lines of hashes)
  run wc -l <"$output_file"
  assert_output "3"
}

@test "Batch: Creates a valid JSON Array container for multiple inputs" {
  local output_file="${TEST_DIR}/manifest.json"

  run "$CHECKIT_EXEC" "${TEST_DIR}/"*.iso -o "$output_file" --format json

  assert_success

  # 1. Verify JSON Structure
  run cat "$output_file"

  # Should start with [ and end with ]
  assert_output --partial "["
  assert_output --partial "]"

  # Should contain all files
  assert_output --partial "archlinux-release.iso"
  assert_output --partial "archlinux-kernel.iso"

  # Should have valid comma separation (implicit check via structure)
  # Basic grep check for 3 objects
  run grep -c "\"filename\"" "$output_file"
  assert_output "3"
}

@test "Batch: Creates a SIGNED container for multiple inputs" {
  local output_file="${TEST_DIR}/SHA256SUMS.asc"

  # Execution: Multiple files + Sign + ASCII Armor
  run "$CHECKIT_EXEC" "${TEST_DIR}/"*.iso --output "$output_file" --sign --armor

  assert_success

  # 1. Verify GPG Armor
  run cat "$output_file"
  assert_output --partial "-----BEGIN PGP SIGNED MESSAGE-----"

  # 2. Verify Content inside armor
  assert_output --partial "archlinux-release.iso"
  assert_output --partial "archlinux-stable.iso"
  assert_output --partial "mock_signature_block"
}
