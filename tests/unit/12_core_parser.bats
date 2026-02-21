#!/usr/bin/env bats
#
# tests/unit/12_core_parser.bats
# Core Parser Unit Tests.
#
# Responsibility: Validate the extraction of Algorithm, Hash, and Filename
# from raw text lines using various formats (BSD tags, GNU standard, Reversed).

load '../test_helper'

setup() {
  load_lib "constants.sh"
  load_lib "core/algorithm_chooser.sh" # Parser depends on this for validation
  load_lib "core/parser.sh"
}

# --- Strategy 1: BSD Explicit Format ---

@test "Parser: BSD format (SHA256)" {
  local hash="5f78c5d32e22641d4017688198944585c5f8749d056321288c347f3a7556a422"
  local line="SHA256 (archive.tar.gz) = $hash"

  run core::parse_line "$line"

  assert_success
  assert_output "sha256|$hash|archive.tar.gz"
}

@test "Parser: BSD format (BLAKE2b -> blake2 normalization)" {
  local hash="abc1234567890abcdef1234567890abcdef1234567890abcdef1234567890abc"
  local line="BLAKE2b (data.iso) = $hash"

  run core::parse_line "$line"

  assert_success
  assert_output "blake2|$hash|data.iso"
}

@test "Parser: BSD format with spaces in filename" {
  local hash="d41d8cd98f00b204e9800998ecf8427e"
  local line="MD5 (file with spaces.txt) = $hash"

  run core::parse_line "$line"

  assert_success
  assert_output "md5|$hash|file with spaces.txt"
}

# --- Strategy 2: Standard GNU Format (HASH  FILENAME) ---

@test "Parser: Standard GNU format (SHA256)" {
  local hash="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  local line="$hash  file.txt"

  run core::parse_line "$line"

  assert_success
  assert_output "sha256|$hash|file.txt"
}

@test "Parser: Standard GNU format with binary marker (*)" {
  local hash="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  local line="$hash *binary_file.bin"

  run core::parse_line "$line"

  assert_success
  # The parser should strip the '*' from the filename
  assert_output "sha256|$hash|binary_file.bin"
}

@test "Parser: Standard GNU format with spaces in filename" {
  local hash="d41d8cd98f00b204e9800998ecf8427e"
  local line="$hash  My Documents/File Name.txt"

  run core::parse_line "$line"

  assert_success
  assert_output "md5|$hash|My Documents/File Name.txt"
}

# --- Strategy 3: Reversed Format (FILENAME HASH) ---

@test "Parser: Reversed format (Filename Hash)" {
  local hash="d41d8cd98f00b204e9800998ecf8427e"
  local line="file.txt $hash"

  run core::parse_line "$line"

  assert_success
  assert_output "md5|$hash|file.txt"
}

# --- Edge Cases & Failures ---

@test "Parser: Ignores comments" {
  run core::parse_line "# This is a comment"
  assert_failure
}

@test "Parser: Ignores empty lines" {
  run core::parse_line "   "
  assert_failure
}

@test "Parser: Fails on invalid line garbage" {
  run core::parse_line "Not a hash line at all"
  assert_failure
}

# --- Strategy 4: JSON Format ---

@test "Parser: JSON format extraction" {
  local hash="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  local line='    { "algorithm": "SHA256", "filename": "config.json", "hash": "'"$hash"'" }'

  run core::parse_line "$line"

  assert_success
  # Algorithm must be normalized to lowercase
  assert_output "sha256|$hash|config.json"
}

@test "Parser: JSON format with escaped characters in filename" {
  local hash="d41d8cd98f00b204e9800998ecf8427e"
  local line='{ "algorithm": "md5", "filename": "file \ name.txt", "hash": "'"$hash"'" }'

  run core::parse_line "$line"

  assert_success
  assert_output "md5|$hash|file \ name.txt"
}

@test "Parser: JSON format structural elements are ignored" {
  # The parser should reject lines that only contain brackets
  run core::parse_line "["
  assert_failure

  run core::parse_line "  ]  "
  assert_failure
}

# --- Strategy 5: XML Format ---

@test "Parser: XML format extraction" {
  local hash="5f78c5d32e22641d4017688198944585c5f8749d056321288c347f3a7556a422"
  local line='  <file algorithm="SHA-256" name="system.iso">'"$hash"'</file>'

  run core::parse_line "$line"

  assert_success
  # Algorithm must be normalized to lowercase
  assert_output "sha-256|$hash|system.iso"
}

@test "Parser: XML format structural tags are ignored" {
  # The parser should reject parent structural tags
  run core::parse_line "<checksums>"
  assert_failure

  run core::parse_line "</checksums>"
  assert_failure
}
