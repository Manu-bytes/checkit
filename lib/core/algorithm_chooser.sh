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
#   Output: Algorithm name (md5, sha1, sha256, sha512)
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
  40)
    echo "sha1"
    return "$EX_SUCCESS"
    ;;
  56) # Nuevo: SHA-224
    echo "sha224"
    return "$EX_SUCCESS"
    ;;
  64)
    echo "sha256"
    return "$EX_SUCCESS"
    ;;
  96) # Nuevo: SHA-384
    echo "sha384"
    return "$EX_SUCCESS"
    ;;
  128)
    echo "sha512"
    return "$EX_SUCCESS"
    ;;
  *)
    return "$EX_OPERATIONAL_ERROR"
    ;;
  esac
}
