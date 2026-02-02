#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"
  source "$PROJECT_ROOT/lib/core/algorithm_chooser.sh"
  TEST_FILE="checksums.asc"
}

teardown() {
  rm -f "$TEST_FILE"
}

@test "Chooser: Identifies algorithm from 'Content-Hash' header" {
  cat <<EOF >"$TEST_FILE"
-----BEGIN PGP SIGNED MESSAGE-----
Content-Hash: sha384

d04b98...  file.iso
-----BEGIN PGP SIGNATURE-----
EOF

  run core::identify_from_file "$TEST_FILE"
  assert_success
  assert_output "sha384"
}

@test "Chooser: IGNORES standard GPG 'Hash:' header (Conflict Scenario)" {
  cat <<EOF >"$TEST_FILE"
-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA512
Content-Hash: sha256

e3b0c4...  file.iso
-----BEGIN PGP SIGNATURE-----
EOF

  run core::identify_from_file "$TEST_FILE"
  assert_success
  assert_output "sha256"
}

@test "Chooser: Returns failure if no Content-Hash is present (even if Hash exists)" {
  cat <<EOF >"$TEST_FILE"
-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA256

hash  file
-----BEGIN PGP SIGNATURE-----
EOF

  run core::identify_from_file "$TEST_FILE"
  assert_failure
}
