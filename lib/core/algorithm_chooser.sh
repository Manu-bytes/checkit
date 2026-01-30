#!/usr/bin/env bash

# core::identify_algorithm
# Arguments: $1 - Hash, $2 - Filename Hint
core::identify_algorithm() {
  local input_hash="${1:-}"
  local filename_hint="${2:-}"

  # Clean spaces
  input_hash="${input_hash//[[:space:]]/}"
  local length="${#input_hash}"

  # Convert filename hint to lowercase for easier matching
  local hint_lower
  hint_lower=$(echo "$filename_hint" | tr '[:upper:]' '[:lower:]')

  case "$length" in
  32)
    if [[ "$hint_lower" == *"b2"* ]] || [[ "$hint_lower" == *"blake"* ]]; then
      echo "blake2-128"
    else
      # Default to MD5
      echo "md5"
    fi
    return "$EX_SUCCESS"
    ;;
  40)
    if [[ "$hint_lower" == *"b2"* ]] || [[ "$hint_lower" == *"blake"* ]]; then
      echo "blake2-160"
    else
      # Default to SHA-1
      echo "sha1"
    fi
    return "$EX_SUCCESS"
    ;;
  56)
    if [[ "$hint_lower" == *"b2"* ]] || [[ "$hint_lower" == *"blake"* ]]; then
      echo "blake2-224"
    else
      # Default to SHA-224
      echo "sha224"
    fi
    return "$EX_SUCCESS"
    ;;
  64)
    if [[ "$hint_lower" == *"b2"* ]] || [[ "$hint_lower" == *"blake"* ]]; then
      echo "blake2-256"
    else
      # Default to SHA-256
      echo "sha256"
    fi
    return "$EX_SUCCESS"
    ;;
  96)
    if [[ "$hint_lower" == *"b2"* ]] || [[ "$hint_lower" == *"blake"* ]]; then
      echo "blake2-384"
    else
      # Default to SHA-384
      echo "sha384"
    fi
    return "$EX_SUCCESS"
    ;;
  128)
    # Resolve SHA-512 vs BLAKE2b collision via file extension.
    if [[ "$hint_lower" == *"b2"* ]] || [[ "$hint_lower" == *"blake"* ]]; then
      echo "blake2"
    else
      # Default to SHA-512
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
    # Example: "Hash: SHA256"
    if [[ "$line" =~ ^Hash:[[:space:]]*([A-Za-z0-9-]+) ]]; then
      local algo="${BASH_REMATCH[1]}"
      echo "$algo" | tr '[:upper:]' '[:lower:]'
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

    # --- 3: GNU HASH HEURISTIC ---
    # Check if the first token looks like a valid hash
    local first_token
    first_token=$(echo "$line" | awk '{print $1}')

    # Ignore GPG boundaries
    if [[ "$first_token" == -* ]]; then continue; fi

    # Test if identify_algorithm recognizes this token
    if output=$(core::identify_algorithm "$first_token" "$file"); then
      echo "$output"
      return "$EX_SUCCESS"
    fi

  done <"$file"

  return "$EX_OPERATIONAL_ERROR"
}
