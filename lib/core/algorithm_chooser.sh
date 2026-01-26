#!/usr/bin/env bash

# core::identify_algorithm
#
# Simple heuristic to determine the hash algorithm based on the length
# of the input string.
#
# Arguments:
#   $1 - Hash string (hexadecimal)
#
# Returns:
#   Output: Algorithm name (md5, sha256)
#   Exit Code: EX_SUCCESS if identified, EX_OPERATIONAL_ERROR if fails.

core::identify_algorithm() {
  local input_hash="${1:-}"
  # We remove blank spaces for security reasons
  input_hash="${input_hash//[[:space:]]/}"
  local length="${#input_hash}"

  case "$length" in
  32)
    echo "md5"
    return "$EX_SUCCESS"
    ;;
  64)
    echo "sha256"
    return "$EX_SUCCESS"
    ;;
  *)
    # Length not recognized
    return "$EX_OPERATIONAL_ERROR"
    ;;
  esac
}
