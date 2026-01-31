#!/usr/bin/env bash

# core::parse_line
# Parses a raw line to extract filename, hash, and algorithm.
#
# Arguments:
#   $1 - Raw text line
#   $2 - (Optional) Sumfile path (used as hint for collision resolution)
#
# Returns:
#   Output: "ALGO|HASH|FILENAME"
core::parse_line() {
  local line="$1"
  local sumfile_hint="${2:-}"

  # 1. Basic cleanup
  line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  if [[ -z "$line" || "$line" == \#* || "$line" == -* ]]; then
    return 1
  fi

  # --- STRATEGY BSD: Explicit Format (ALGO (file) = hash) ---
  # Regex: Start with word, space, (, anything, ), space, =, space, hash
  if [[ "$line" =~ ^([A-Za-z0-9-]+)[[:space:]]*\((.+)\)[[:space:]]*=[[:space:]]*([a-fA-F0-9]+)$ ]]; then
    local algo_tag="${BASH_REMATCH[1]}"
    local filename="${BASH_REMATCH[2]}"
    local hash="${BASH_REMATCH[3]}"

    # Normalize algo name (BLAKE2b -> blake2)
    local algo_lower
    algo_lower=$(echo "$algo_tag" | tr '[:upper:]' '[:lower:]')
    if [[ "$algo_lower" == "blake2b" ]]; then algo_lower="blake2"; fi

    echo "$algo_lower|$hash|$filename"
    return 0
  fi

  # --- STRATEGY A: Standard Format (HASH  FILENAME) ---
  local first_token
  first_token=$(echo "$line" | awk '{print $1}')
  local clean_first
  clean_first=$(echo "$first_token" | sed 's/^[\(<]//;s/[\)>]$//')

  # Pass sumfile_hint to identify_algorithm to resolve collisions (SHA512 vs BLAKE2)
  if output=$(core::identify_algorithm "$clean_first" "$sumfile_hint"); then
    local detected_algo="$output"
    local detected_hash="$clean_first"
    local filename
    # shellcheck disable=SC2001
    filename=$(echo "$line" | sed "s/^${first_token}[[:space:]]*//")
    filename="${filename#\*}" # Remove binary marker

    echo "$detected_algo|$detected_hash|$filename"
    return 0
  fi

  # --- STRATEGY B: Reversed Format (FILENAME HASH) ---
  local last_token
  last_token=$(echo "$line" | awk '{print $NF}')
  local clean_last
  clean_last=$(echo "$last_token" | sed 's/^[\(<]//;s/[\)>]$//')

  if output=$(core::identify_algorithm "$clean_last" "$sumfile_hint"); then
    local detected_algo="$output"
    local detected_hash="$clean_last"
    local filename
    # Remove the last token from the end of the line
    # shellcheck disable=SC2001
    filename=$(echo "$line" | sed "s/[[:space:]]*$last_token$//")
    filename="${filename#\*}"

    echo "$detected_algo|$detected_hash|$filename"
    return 0
  fi

  return 2
}
