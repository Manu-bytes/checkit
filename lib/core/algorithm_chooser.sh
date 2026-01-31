#!/usr/bin/env bash

# core::identify_algorithm
#
# Determines the hash algorithm based on string length and optional hints
# to resolve collisions.
#
# Arguments:
#   $1 - Hash string (hexadecimal)
#   $2 - (Optional) Filename hint for disambiguation
#
# Returns:
#   Output: Algorithm name (md5, sha1, sha256, sha512, blake2, etc.)
#   Exit Code: EX_SUCCESS if identified, EX_OPERATIONAL_ERROR if fails.

core::identify_algorithm() {
  local input_hash="${1:-}"
  local filename_hint="${2:-}"

  # Remove whitespace
  input_hash="${input_hash//[[:space:]]/}"

  # STRICT VALIDATION: Ensure input is strictly hexadecimal.
  # This prevents filenames with similar lengths (e.g., 32 chars)
  # from being misidentified as hashes by the parser.
  if [[ ! "$input_hash" =~ ^[a-fA-F0-9]+$ ]]; then
    return "$EX_OPERATIONAL_ERROR"
  fi

  local length="${#input_hash}"

  # Convert hint to lowercase for matching
  local hint_lower
  hint_lower=$(echo "$filename_hint" | tr '[:upper:]' '[:lower:]')

  case "$length" in
  32)
    # 32 chars = 128 bits (MD5 or BLAKE2-128)
    if [[ "$hint_lower" == *"b2"* ]] || [[ "$hint_lower" == *"blake"* ]]; then
      echo "blake2-128"
    else
      echo "md5"
    fi
    return "$EX_SUCCESS"
    ;;
  40)
    # 40 chars = 160 bits (SHA-1 or BLAKE2-160)
    if [[ "$hint_lower" == *"b2"* ]] || [[ "$hint_lower" == *"blake"* ]]; then
      echo "blake2-160"
    else
      echo "sha1"
    fi
    return "$EX_SUCCESS"
    ;;
  56)
    # 56 chars = 224 bits (SHA-224 or BLAKE2-224)
    if [[ "$hint_lower" == *"b2"* ]] || [[ "$hint_lower" == *"blake"* ]]; then
      echo "blake2-224"
    else
      echo "sha224"
    fi
    return "$EX_SUCCESS"
    ;;
  64)
    # 64 chars = 256 bits (SHA-256 or BLAKE2-256)
    if [[ "$hint_lower" == *"b2"* ]] || [[ "$hint_lower" == *"blake"* ]]; then
      echo "blake2-256"
    else
      echo "sha256"
    fi
    return "$EX_SUCCESS"
    ;;
  96)
    # 96 chars = 384 bits (SHA-384 or BLAKE2-384)
    if [[ "$hint_lower" == *"b2"* ]] || [[ "$hint_lower" == *"blake"* ]]; then
      echo "blake2-384"
    else
      echo "sha384"
    fi
    return "$EX_SUCCESS"
    ;;
  128)
    # 128 chars = 512 bits (SHA-512 or BLAKE2b)
    # Resolve collision using file extension/name hint
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

# core::identify_from_file
# Scans the first lines of the file looking for algorithm clues.
# Supports GPG headers, BSD tags, and GNU standard format.
#
# Arguments:
#   $1 - Path to the checksums file
#
# Returns:
#   Output: Name of the algorithm (e.g., sha256)
#   Exit Code: EX_SUCCESS or error.

core::identify_from_file() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    return "$EX_OPERATIONAL_ERROR"
  fi

  # Read up to 21 lines searching for a valid match.
  local max_lines=21
  local count=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    count=$((count + 1))
    if [[ "$count" -gt "$max_lines" ]]; then
      break
    fi

    # Basic cleanup
    line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    if [[ -z "$line" ]]; then continue; fi

    # --- 1: GPG HEADER DETECTION ---
    # Matches: "Hash: SHA256", "Hash: b2-128", "Hash: SHA-512"
    if [[ "$line" =~ ^Hash:[[:space:]]*([A-Za-z0-9-]+) ]]; then
      local raw_algo="${BASH_REMATCH[1]}"

      # 1. Normalize to lowercase
      local algo
      algo=$(echo "$raw_algo" | tr '[:upper:]' '[:lower:]')

      # 2. Normalize aliases
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

    # --- 2: BSD TAG DETECTION ---
    # Example: "SHA256 (file) = hash" or "BLAKE2b (file) = hash"
    local line_upper
    line_upper=$(echo "$line" | tr '[:lower:]' '[:upper:]')

    # Regex allows optional 'B' or 'S' suffix for BLAKE2 (e.g., BLAKE2B)
    if [[ "$line_upper" =~ ^(SHA256|SHA512|SHA1|MD5|BLAKE2[BS]?)[[:space:]]*\( ]]; then
      local algo_raw="${BASH_REMATCH[1]}"

      # Normalize BLAKE2B to blake2 for adapter compatibility
      if [[ "$algo_raw" == "BLAKE2B" ]]; then
        echo "blake2"
      else
        echo "$algo_raw" | awk '{print tolower($1)}'
      fi
      return "$EX_SUCCESS"
    fi
  done <"$file"

  return "$EX_OPERATIONAL_ERROR"
}
