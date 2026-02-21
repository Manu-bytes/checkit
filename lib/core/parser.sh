#!/usr/bin/env bash
#
# lib/core/parser.sh
# Core Parser: Checksum line parsing logic.
#
# Responsibility: Deconstruct raw text lines into structured components
# (Algorithm, Hash, Filename) using various strategy patterns
# (JSON, XML, BSD, GNU, Reversed).

# ----------------------------------------------------------------------
# Public Functions
# ----------------------------------------------------------------------

# Public: Parses a raw text line to extract the checksum components.
# Attempts multiple parsing strategies.
#
# $1 - line         - The raw text line to parse.
# $2 - sumfile_hint - (Optional) Path to the source file to aid algorithm detection.
#
# Returns 0 on success (echoes "ALGO|HASH|FILENAME"), or non-zero on failure.
core::parse_line() {
  local line="$1"
  local sumfile_hint="${2:-}"

  # 1. Basic Cleanup (Bash Native)
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"

  # Ignore empty lines, comments, or PGP headers
  if [[ -z "$line" || "$line" == \#* ]]; then return 1; fi
  if [[ "$line" =~ ^----- ]]; then return 1; fi
  if [[ "$line" =~ ^Hash: ]]; then return 1; fi

  # Ignore Structural Elements (JSON brackets, XML tags)
  if [[ "$line" =~ ^[[:space:]]*[\{\}\[\]][[:space:]]*$ ]]; then return 1; fi
  if [[ "$line" =~ ^[[:space:]]*\<[\/]?checksums\> ]]; then return 1; fi

  # --- STRATEGY 1: JSON Format ---
  # Pattern: { "algorithm": "...", "filename": "...", "hash": "..." }
  if [[ "$line" =~ \"algorithm\":[[:space:]]*\"([^\"]+)\".*\"filename\":[[:space:]]*\"([^\"]+)\".*\"hash\":[[:space:]]*\"([^\"]+)\" ]]; then
    local algo="${BASH_REMATCH[1]}"
    local file="${BASH_REMATCH[2]}"
    local hash="${BASH_REMATCH[3]}"
    # JSON usually has normalized algos, but we ensure lowercase
    echo "${algo,,}|$hash|$file"
    return 0
  fi

  # --- STRATEGY 2: XML Format ---
  # Pattern: <file algorithm="..." name="...">HASH</file>
  if [[ "$line" =~ \<file[[:space:]]+algorithm=\"([^\"]+)\"[[:space:]]+name=\"([^\"]+)\"\>([^<]+)\<\/file\> ]]; then
    local algo="${BASH_REMATCH[1]}"
    local file="${BASH_REMATCH[2]}"
    local hash="${BASH_REMATCH[3]}"
    echo "${algo,,}|$hash|$file"
    return 0
  fi

  # --- STRATEGY 3: BSD Explicit Format ---
  # Pattern: ALGO (file) = hash
  if [[ "$line" =~ ^([A-Za-z0-9-]+)[[:space:]]*\((.+)\)[[:space:]]*=[[:space:]]*([a-fA-F0-9]+)$ ]]; then
    local algo_tag="${BASH_REMATCH[1]}"
    local filename="${BASH_REMATCH[2]}"
    local hash="${BASH_REMATCH[3]}"
    local algo_lower="${algo_tag,,}"

    if [[ "$algo_lower" == "blake2b" ]]; then algo_lower="blake2"; fi
    echo "$algo_lower|$hash|$filename"
    return 0
  fi

  # --- STRATEGY 4: Standard Format (HASH  FILENAME) ---
  local first_token="${line%%[[:space:]]*}"
  local clean_first="${first_token//[()<>]/}"

  if output=$(core::identify_algorithm "$clean_first" "$sumfile_hint"); then
    local detected_algo="$output"
    local detected_hash="$clean_first"
    local filename="${line#"$first_token"}"
    filename="${filename#"${filename%%[![:space:]]*}"}" # Trim leading space

    if [[ "$filename" == \** ]]; then filename="${filename:1}"; fi

    echo "$detected_algo|$detected_hash|$filename"
    return 0
  fi

  # --- STRATEGY 5: Reversed Format (FILENAME HASH) ---
  local last_token="${line##*[[:space:]]}"
  local clean_last="${last_token//[()<>]/}"

  if output=$(core::identify_algorithm "$clean_last" "$sumfile_hint"); then
    local detected_algo="$output"
    local detected_hash="$clean_last"
    local filename="${line%"$last_token"}"
    filename="${filename%"${filename##*[![:space:]]}"}" # Trim trailing space

    if [[ "$filename" == \** ]]; then filename="${filename:1}"; fi

    echo "$detected_algo|$detected_hash|$filename"
    return 0
  fi

  return 2
}
