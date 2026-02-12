#!/usr/bin/env bash
#
# lib/core/algorithm_chooser.sh
# Algorithm Detection Core: Identifies hash algorithms.
#
# Responsibility: Deduce the cryptographic algorithm based on hash string length
# or specific file headers/tags within checksum files.

# ----------------------------------------------------------------------
# Public Functions
# ----------------------------------------------------------------------

# Public: Determines the hash algorithm based on string length.
# Uses an optional filename hint to resolve collisions (e.g., SHA-512 vs Blake2b).
#
# $1 - input_hash    - The hexadecimal hash string to analyze.
# $2 - filename_hint - (Optional) A filename string to aid disambiguation.
#
# Returns the algorithm name to stdout, or exits with EX_OPERATIONAL_ERROR if invalid.
core::identify_algorithm() {
  local input_hash="${1:-}"
  local filename_hint="${2:-}"

  # 1. Normalize Input
  # Remove all whitespace to ensure accurate length calculation.
  input_hash="${input_hash//[[:space:]]/}"

  # 2. Strict Validation
  # Ensure input contains only hexadecimal characters.
  if [[ ! "$input_hash" =~ ^[a-fA-F0-9]+$ ]]; then
    return "$EX_OPERATIONAL_ERROR"
  fi

  local length="${#input_hash}"

  # 3. Normalize Hint
  # Convert to lowercase using Bash 4.0+ operator for performance.
  local hint_lower="${filename_hint,,}"

  case "$length" in
  32)
    # 128 bits: MD5 or BLAKE2-128
    if [[ "$hint_lower" == *"b2"* ]] || [[ "$hint_lower" == *"blake"* ]]; then
      echo "blake2-128"
    else
      echo "md5"
    fi
    return "$EX_SUCCESS"
    ;;
  40)
    # 160 bits: SHA-1 or BLAKE2-160
    if [[ "$hint_lower" == *"b2"* ]] || [[ "$hint_lower" == *"blake"* ]]; then
      echo "blake2-160"
    else
      echo "sha1"
    fi
    return "$EX_SUCCESS"
    ;;
  56)
    # 224 bits: SHA-224 or BLAKE2-224
    if [[ "$hint_lower" == *"b2"* ]] || [[ "$hint_lower" == *"blake"* ]]; then
      echo "blake2-224"
    else
      echo "sha224"
    fi
    return "$EX_SUCCESS"
    ;;
  64)
    # 256 bits: SHA-256 or BLAKE2-256
    if [[ "$hint_lower" == *"b2"* ]] || [[ "$hint_lower" == *"blake"* ]]; then
      echo "blake2-256"
    else
      echo "sha256"
    fi
    return "$EX_SUCCESS"
    ;;
  96)
    # 384 bits: SHA-384 or BLAKE2-384
    if [[ "$hint_lower" == *"b2"* ]] || [[ "$hint_lower" == *"blake"* ]]; then
      echo "blake2-384"
    else
      echo "sha384"
    fi
    return "$EX_SUCCESS"
    ;;
  128)
    # 512 bits: SHA-512 or BLAKE2b
    if [[ "$hint_lower" == *"b2"* ]] || [[ "$hint_lower" == *"blake"* ]]; then
      echo "blake2"
    else
      echo "sha512"
    fi
    return "$EX_SUCCESS"
    ;;
  *)
    return "$EX_OPERATIONAL_ERROR"
    ;;
  esac
}

# Public: Scans a file header to identify the algorithm used.
# Supports 'Content-Hash' headers and BSD-style tags.
# Reads a limited number of lines to prevent performance issues on large files.
#
# $1 - file - The path to the checksums file.
#
# Returns the algorithm name to stdout on success.
core::identify_from_file() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    return "$EX_OPERATIONAL_ERROR"
  fi

  local max_lines=21
  local count=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    count=$((count + 1))
    if [[ "$count" -gt "$max_lines" ]]; then
      break
    fi

    # 1. Trim whitespace (Bash Native)
    # Removes leading and trailing spaces without spawning subshells (sed).
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    if [[ -z "$line" ]]; then continue; fi

    # --- Strategy A: Content-Hash Header ---
    # Matches: "Content-Hash: SHA256", "Content-Hash: blake2b"
    if [[ "$line" =~ ^Content-Hash:[[:space:]]*([A-Za-z0-9-]+) ]]; then
      local raw_algo="${BASH_REMATCH[1]}"

      # Normalize to lowercase (Bash Native)
      local algo="${raw_algo,,}"

      # Normalize aliases
      # Handle "b2-" prefix -> "blake2-"
      if [[ "$algo" == "b2"* ]]; then
        algo="${algo/b2/blake2}"
      fi

      # Handle "sha-" prefix (e.g. sha-256 -> sha256)
      if [[ "$algo" == "sha-"* ]]; then
        algo="${algo//-/}"
      fi

      echo "$algo"
      return "$EX_SUCCESS"
    fi

    # --- Strategy B: BSD Tag Detection ---
    # Matches: "SHA256 (file) = hash"
    # Use uppercase for regex matching
    local line_upper="${line^^}"

    if [[ "$line_upper" =~ ^(SHA256|SHA512|SHA1|MD5|BLAKE2[BS]?)[[:space:]]*\( ]]; then
      local algo_raw="${BASH_REMATCH[1]}"

      # Normalize BLAKE2B/BLAKE2S
      if [[ "$algo_raw" == "BLAKE2B" ]]; then
        echo "blake2"
      else
        # Convert to lowercase (Bash Native)
        echo "${algo_raw,,}"
      fi
      return "$EX_SUCCESS"
    fi
  done <"$file"

  return "$EX_OPERATIONAL_ERROR"
}
