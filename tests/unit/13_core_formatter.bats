#!/usr/bin/env bats
#
# tests/unit/13_core_formatter.bats
# Core Formatter Unit Tests.
#
# Responsibility: Verify that hash entries are formatted correctly according
# to the specified standard (GNU, BSD, JSON, XML) and that special characters
# are escaped to prevent syntax errors.

load '../test_helper'

setup() {
  load_lib "core/formatter.sh"
}

# --- Format: GNU (Default) ---

@test "Formatter: GNU format outputs 'HASH  FILE'" {
  run core::format_hash "gnu" "sha256" "file.txt" "hash123"
  assert_success
  assert_output "hash123  file.txt"
}

# --- Format: BSD ---

@test "Formatter: BSD format outputs 'ALGO (File) = Hash'" {
  run core::format_hash "bsd" "sha256" "file.txt" "hash123"
  assert_success
  # Expecting uppercase algorithm
  assert_output "SHA256 (file.txt) = hash123"
}

# --- Format: JSON ---

@test "Formatter: JSON format outputs valid object field" {
  run core::format_hash "json" "sha256" "file.txt" "hash123"
  assert_success
  # We check for key components since whitespace might vary slightly
  assert_output --partial '"algorithm": "SHA256"'
  assert_output --partial '"filename": "file.txt"'
  assert_output --partial '"hash": "hash123"'
}

@test "Formatter: JSON format escapes special characters" {
  # Filename with quotes and backslashes
  local weird_file='file "name" \ with backslash.txt'

  run core::format_hash "json" "md5" "$weird_file" "hash123"

  assert_success
  # Quote should be escaped \"
  assert_output --partial '\"name\"'
  # Backslash should be escaped \\
  assert_output --partial '\\ with'
}

# --- Format: XML ---

@test "Formatter: XML format outputs <file> element" {
  run core::format_hash "xml" "SHA256" "file.txt" "hash123"
  assert_success
  assert_output '  <file algorithm="SHA256" name="file.txt">hash123</file>'
}

@test "Formatter: XML format escapes special attributes" {
  # Filename with XML special chars: <, >, &, "
  local weird_file='<file> & "quote"'

  run core::format_hash "xml" "MD5" "$weird_file" "hash123"

  assert_success
  # & -> &amp;
  assert_output --partial '&amp;'
  # < -> &lt;
  assert_output --partial '&lt;file&gt;'
  # " -> &quot;
  assert_output --partial '&quot;quote&quot;'
}
