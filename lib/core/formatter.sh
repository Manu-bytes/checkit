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
  local output="${input//&/&amp;}" # Ampersand first
  output="${output//</&lt;}"       # Less than
  output="${output//>/&gt;}"       # Greater than
  output="${output//\"/&quot;}"    # Double quote
  output="${output//\'/&apos;}"    # Single quote
  echo "$output"
}

# ----------------------------------------------------------------------
# Public Functions
# ----------------------------------------------------------------------

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
    # BSD Format: ALGO (File) = Hash
    # uses Bash Parameter Expansion (^^) for uppercase (Bash 4.0+)
    echo "${algo^^} ($file) = $hash"
    ;;

  json)
    # JSON Object Element
    # Note: Comma handling for lists is the responsibility of the caller.
    local safe_file
    safe_file=$(_escape_json "$file")
    echo "    { \"algorithm\": \"$algo\", \"filename\": \"$safe_file\", \"hash\": \"$hash\" }"
    ;;

  xml)
    # XML Element
    local safe_file
    safe_file=$(_escape_xml "$file")
    local safe_algo
    safe_algo=$(_escape_xml "$algo")
    echo "  <file algorithm=\"$safe_algo\" name=\"$safe_file\">$hash</file>"
    ;;

  *)
    # GNU / Default: Hash  File
    # Two spaces between hash and filename is the standard GNU Coreutils format.
    echo "$hash  $file"
    ;;
  esac
}
