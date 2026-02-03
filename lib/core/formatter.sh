#!/usr/bin/env bash

# core::escape_json
# Escapes special characters for valid JSON strings.
# Args: $1 - raw string
core::escape_json() {
  local input="$1"
  local output="${input//\\/\\\\}" # Escape backslashes
  output="${output//\"/\\\"}"      # Escape quotes
  output="${output//$'\n'/\\n}"    # Escape newlines
  output="${output//$'\r'/\\r}"    # Escape carriage returns
  output="${output//$'\t'/\\t}"    # Escape tabs
  echo "$output"
}

# core::format_hash
# Formats a single hash entry based on the selected format.
# Args: $1 - format (gnu, bsd, json, xml)
#       $2 - algorithm
#       $3 - filename
#       $4 - hash
core::format_hash() {
  local fmt="$1"
  local algo="$2"
  local file="$3"
  local hash="$4"

  case "$fmt" in
  bsd)
    # BSD format: ALGO (File) = Hash
    echo "${algo^^} ($file) = $hash"
    ;;
  json)
    # JSON Object element (Note: Comma handling is done by the caller)
    local safe_file
    safe_file=$(core::escape_json "$file")
    echo "    { \"algorithm\": \"$algo\", \"filename\": \"$safe_file\", \"hash\": \"$hash\" }"
    ;;
  xml)
    # XML Element
    # Basic XML escaping for attributes should be added if strictness is required.
    # For now, assuming standard filenames.
    echo "  <file algorithm=\"$algo\" name=\"$file\">$hash</file>"
    ;;
  *)
    # GNU / Default: Hash  File
    echo "$hash  $file"
    ;;
  esac
}
