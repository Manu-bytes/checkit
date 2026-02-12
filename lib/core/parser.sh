#!/usr/bin/env bash
#
# lib/core/parser.sh
# Core Parser: Checksum line parsing logic.
#
# Responsibility: Deconstruct raw text lines into structured components
# (Algorithm, Hash, Filename) using various strategy patterns (BSD, GNU, Reversed).

# ----------------------------------------------------------------------
# Public Functions
# ----------------------------------------------------------------------

# Public: Parses a raw text line to extract the checksum components.
# Attempts multiple parsing strategies (BSD tag, Standard, Reversed).
#
# $1 - line         - The raw text line to parse.
# $2 - sumfile_hint - (Optional) Path to the source file to aid algorithm detection
#                     (resolves collisions like SHA-512 vs Blake2b).
#
# Returns 0 on success (echoes "ALGO|HASH|FILENAME"), or non-zero on failure.
core::parse_line() {
  local line="$1"
  local sumfile_hint="${2:-}"

  # 1. Basic Cleanup (Bash Native)
  # Trim leading whitespace
  line="${line#"${line%%[![:space:]]*}"}"
  # Trim trailing whitespace
  line="${line%"${line##*[![:space:]]}"}"

  # Ignore empty lines or comments
  if [[ -z "$line" || "$line" == \#* ]]; then
    return 1
  fi

  # --- STRATEGY 1: BSD Explicit Format ---
  # Pattern: ALGO (file) = hash
  # Regex capture: 1=Algo, 2=Filename, 3=Hash
  if [[ "$line" =~ ^([A-Za-z0-9-]+)[[:space:]]*\((.+)\)[[:space:]]*=[[:space:]]*([a-fA-F0-9]+)$ ]]; then
    local algo_tag="${BASH_REMATCH[1]}"
    local filename="${BASH_REMATCH[2]}"
    local hash="${BASH_REMATCH[3]}"

    # Normalize algo name (Bash 4.0+ case conversion)
    local algo_lower="${algo_tag,,}"

    # Handle specific BSD aliases
    if [[ "$algo_lower" == "blake2b" ]]; then algo_lower="blake2"; fi

    echo "$algo_lower|$hash|$filename"
    return 0
  fi

  # --- STRATEGY 2: Standard Format (HASH  FILENAME) ---
  # Extract first word (Hash candidate)
  local first_token="${line%%[[:space:]]*}"

  # Clean potential wrappers like parenthesis (rare edge cases)
  local clean_first="${first_token//[()<>]/}"

  if output=$(core::identify_algorithm "$clean_first" "$sumfile_hint"); then
    local detected_algo="$output"
    local detected_hash="$clean_first"

    # Extract filename: Remove hash and leading spaces
    local filename="${line#"$first_token"}"
    filename="${filename#"${filename%%[![:space:]]*}"}" # Trim leading space

    # Remove binary marker '*' if present at start of filename
    if [[ "$filename" == \** ]]; then
      filename="${filename:1}"
    fi

    echo "$detected_algo|$detected_hash|$filename"
    return 0
  fi

  # --- STRATEGY 3: Reversed Format (FILENAME HASH) ---
  # Extract last word (Hash candidate)
  local last_token="${line##*[[:space:]]}"

  local clean_last="${last_token//[()<>]/}"

  if output=$(core::identify_algorithm "$clean_last" "$sumfile_hint"); then
    local detected_algo="$output"
    local detected_hash="$clean_last"

    # Extract filename: Remove hash from end
    local filename="${line%"$last_token"}"
    filename="${filename%"${filename##*[![:space:]]}"}" # Trim trailing space

    # Remove binary marker '*' if present (logic implies it would be at start)
    if [[ "$filename" == \** ]]; then
      filename="${filename:1}"
    fi

    echo "$detected_algo|$detected_hash|$filename"
    return 0
  fi

  return 2
}
