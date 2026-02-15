#!/usr/bin/env bash
#
# lib/core/formatter.sh
# Core Formatter: Transforms raw hash data into structured output.
#
# Responsibility: Format algorithm, filename, and hash strings into
# specific standards (BSD, GNU, JSON, XML) ensuring proper character escaping.

# ----------------------------------------------------------------------
# Internal Helper Functions
# ----------------------------------------------------------------------

# Internal: Escapes control characters for JSON string compliance.
# Handles backslashes, quotes, newlines, carriage returns, and tabs.
#
# $1 - input - The raw string to escape.
#
# Returns the escaped string to stdout.
_escape_json() {
  local input="$1"
  local output="${input//\\/\\\\}" # Escape backslashes first
  output="${output//\"/\\\"}"      # Escape quotes
  output="${output//$'\n'/\\n}"    # Escape newlines
  output="${output//$'\r'/\\r}"    # Escape carriage returns
  output="${output//$'\t'/\\t}"    # Escape tabs
  echo "$output"
}

# Internal: Escapes special characters for XML attribute compliance.
# Handles &, <, >, ", and '.
#
# $1 - input - The raw string to escape.
#
# Returns the escaped string to stdout.
_escape_xml() {
  local input="$1"
  local output="${input//&/\&amp;}" # Ampersand
  output="${output//</\&lt;}"       # Less than
  output="${output//>/\&gt;}"       # Greater than
  output="${output//\"/\&quot;}"    # Double quote
  output="${output//\'/\&apos;}"    # Single quote
  echo "$output"
}

# ----------------------------------------------------------------------
# Public Functions
# ----------------------------------------------------------------------

# Public: Exposes the canonical tag generation logic.
# Use this when generating headers (Content-Hash) to match BSD/XML/JSON tags.
#
# $1 - algo - The internal algorithm slug (e.g., b2, sha256).
#
# Returns the official BSD tag (e.g., BLAKE2b, SHA256).
core::get_tag() {
  local algo="$1"
  case "$algo" in
  # Blake Family
  b2 | blake2 | blake2b) echo "BLAKE2" ;;
  b2-128 | blake2-128 | blake2b-128) echo "BLAKE2-128" ;;
  b2-160 | blake2-160 | blake2b-160) echo "BLAKE2-160" ;;
  b2-224 | blake2-224 | blake2b-224) echo "BLAKE2-224" ;;
  b2-256 | blake2-256 | blake2b-256) echo "BLAKE2-256" ;;
  b2-384 | blake2-384 | blake2b-384) echo "BLAKE2-384" ;;

  # SHA Family (Standard usually uppercase)
  sha1) echo "SHA1" ;;
  sha224) echo "SHA224" ;;
  sha256) echo "SHA256" ;;
  sha384) echo "SHA384" ;;
  sha512) echo "SHA512" ;;

  # Legacy
  md5) echo "MD5" ;;

  # Fallback: Just Uppercase it
  *) echo "${algo^^}" ;;
  esac
}

# Public: Formats a single hash entry based on the selected standard.
# Dispatches the input to the correct formatting logic.
#
# $1 - fmt   - The output format string (gnu, bsd, json, xml).
# $2 - algo  - The algorithm name (e.g., sha256).
# $3 - file  - The filename associated with the hash.
# $4 - hash  - The calculated hexadecimal hash string.
#
# Returns the formatted string to stdout.
core::format_hash() {
  local fmt="$1"
  local algo="$2"
  local file="$3"
  local hash="$4"

  case "$fmt" in
  bsd)
    # BSD Tagged Format: ALGO (File) = Hash
    # FIX: Usamos la función de mapeo en lugar de usar $algo directamente
    local tag
    tag=$(core::get_tag "$algo")
    echo "$tag ($file) = $hash"
    ;;

  json)
    # JSON Object Element
    # Note: Comma handling for lists is the responsibility of the caller.
    local safe_file
    safe_file=$(_escape_json "$file")
    echo "    { \"algorithm\": \"$(core::get_tag "$algo")\", \"filename\": \"$safe_file\", \"hash\": \"$hash\" }"
    ;;

  xml)
    # XML Element
    local safe_file
    safe_file=$(_escape_xml "$file")
    local safe_algo
    safe_algo=$(_escape_xml "$(core::get_tag "$algo")")
    echo "  <file algorithm=\"$safe_algo\" name=\"$safe_file\">$hash</file>"
    ;;

  *)
    # GNU / Default: Hash  File
    # Two spaces between hash and filename is the standard GNU Coreutils format.
    echo "$hash  $file"
    ;;
  esac
}
