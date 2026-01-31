#!/usr/bin/env bash

# Helper: Map algorithm string to corresponding binary.
__resolve_cmd() {
  local algo="$1"
  if [[ "$algo" == "blake2"* ]]; then echo "b2sum"; else echo "${algo}sum"; fi
}

# Helper: Get fallback algorithm for blind ambiguity.
__get_fallback_algo() {
  local algo="$1"
  case "$algo" in
  md5) echo "blake2-128" ;;
  sha1) echo "blake2-160" ;;
  sha224) echo "blake2-224" ;;
  sha256) echo "blake2-256" ;;
  sha384) echo "blake2-384" ;;
  sha512) echo "blake2" ;;
  *) echo "" ;;
  esac
}

# Helper: Return expected hash length for a given algorithm.
# Used for "Format Integrity" validation.
__get_algo_length() {
  local algo="$1"
  case "$algo" in
  md5 | blake2-128) echo 32 ;;
  sha1 | blake2-160) echo 40 ;;
  sha224 | blake2-224) echo 56 ;;
  sha256 | blake2-256) echo 64 ;;
  sha384 | blake2-384) echo 96 ;;
  sha512 | blake2) echo 128 ;;
  *) echo 0 ;;
  esac
}

# coreutils::verify
coreutils::verify() {
  local algo="$1"
  local file="$2"
  local expected_hash="$3"

  if [[ ! -f "$file" ]]; then return "$EX_OPERATIONAL_ERROR"; fi
  local cmd
  cmd=$(__resolve_cmd "$algo")
  if echo "${expected_hash}  ${file}" | "$cmd" -c - >/dev/null 2>&1; then
    return "$EX_SUCCESS"
  else
    return "$EX_INTEGRITY_FAIL"
  fi
}

# coreutils::check_list
# Implements the 3-Level Optimization Hierarchy:
# 1. Strict Naming (SHAxSUMS)
# 2. Internal Metadata (Hash: SHAx)
# 3. General Compatibility (Mixed/Fallback)
coreutils::check_list() {
  local _ignored="$1"
  local sumfile="$2"

  if [[ ! -f "$sumfile" ]]; then return "$EX_OPERATIONAL_ERROR"; fi

  local strict_algo=""
  local fname_lower
  fname_lower=$(basename "$sumfile" | tr '[:upper:]' '[:lower:]')

  # --- 1: STRICT NOMENCLATURE DETECTION ---
  # Regex para capturar shaxsum, md5sum, b2sum
  if [[ "$fname_lower" =~ ^(md5|sha1|sha224|sha256|sha384|sha512|b2|blake2) ]]; then
    local match="${BASH_REMATCH[1]}"
    if [[ "$match" == "b2" || "$match" == "blake2" ]]; then
      strict_algo="blake_family"
    else
      strict_algo="$match"
    fi
  fi
  # --- 1.5: FAMILY RESTRICTION (Generic) ---
  if [[ -z "$strict_algo" ]]; then
    if [[ "$fname_lower" == *"sha"* || "$fname_lower" == *"md5"* ]]; then
      family_constraint="gnu"
    elif [[ "$fname_lower" == *"b2"* || "$fname_lower" == *"blake"* ]]; then
      family_constraint="blake"
    fi
  fi
  # --- 2: DETECTION BY INTERNAL METADATA ---
  if [[ -z "$strict_algo" ]]; then
    local meta_algo
    if meta_algo=$(core::identify_from_file "$sumfile"); then
      strict_algo="$meta_algo"
    fi
  fi

  local failures=0
  local verified_count=0

  # Line-by-Line Processing
  while IFS= read -r line <&3 || [[ -n "$line" ]]; do
    local parsed
    if ! parsed=$(core::parse_line "$line" "$sumfile"); then continue; fi

    local detected_algo
    local hash_line
    local file_line
    detected_algo=$(echo "$parsed" | cut -d'|' -f1)
    hash_line=$(echo "$parsed" | cut -d'|' -f2)
    file_line=$(echo "$parsed" | cut -d'|' -f3)

    if [[ ! -f "$file_line" ]]; then
      echo "[MISSING] $file_line"
      failures=$((failures + 1))
      continue
    fi

    # --- LOGICA DE VERIFICACIÓN JERÁRQUICA ---

    if [[ -n "$strict_algo" && "$strict_algo" != "blake_family" ]]; then
      # CASE: Specific Imposed Algorithm
      local expected_len
      expected_len=$(__get_algo_length "$strict_algo")
      local current_len="${#hash_line}"

      if [[ "$expected_len" -ne "$current_len" ]]; then
        echo "[SKIPPED] $file_line (Format mismatch: expected $strict_algo)"
        continue
      fi

      if coreutils::verify "$strict_algo" "$file_line" "$hash_line"; then
        echo "[OK] $file_line ($strict_algo)"
        verified_count=$((verified_count + 1))
      else
        echo "[FAILED] $file_line ($strict_algo)"
        failures=$((failures + 1))
      fi

    elif [[ "$strict_algo" == "blake_family" ]]; then
      # CASE: The Strict Blake Family (b2sums)
      local target_algo="$detected_algo"
      if [[ "$detected_algo" == "sha"* || "$detected_algo" == "md5" ]]; then
        target_algo=$(__get_fallback_algo "$detected_algo")
      fi

      if coreutils::verify "$target_algo" "$file_line" "$hash_line"; then
        echo "[OK] $file_line ($target_algo)"
        verified_count=$((verified_count + 1))
      else
        echo "[FAILED] $file_line ($target_algo)"
        failures=$((failures + 1))
      fi

    else
      # --- LEVEL 3: MIXED MODE WITH FAMILY PROTECTION ---
      # 1. Attempt detected algorithm
      if coreutils::verify "$detected_algo" "$file_line" "$hash_line"; then
        echo "[OK] $file_line ($detected_algo)"
        verified_count=$((verified_count + 1))
      else
        # 2. Fallback Logic
        local fallback_algo
        fallback_algo=$(__get_fallback_algo "$detected_algo")
        local allow_fallback=true

        if [[ "$family_constraint" == "gnu" ]]; then
          # Si el archivo es GNU (shasums), prohibido fallback a Blake
          if [[ "$fallback_algo" == "blake"* ]]; then allow_fallback=false; fi
        elif [[ "$family_constraint" == "blake" ]]; then
          # Si el archivo es Blake, prohibido fallback a SHA (raro, pero posible)
          if [[ "$fallback_algo" != "blake"* ]]; then allow_fallback=false; fi
        fi

        local recovered=false
        if [[ -n "$fallback_algo" && "$allow_fallback" == "true" ]]; then
          if coreutils::verify "$fallback_algo" "$file_line" "$hash_line"; then
            echo "[OK] $file_line ($fallback_algo)"
            verified_count=$((verified_count + 1))
            recovered=true
          fi
        fi

        if [[ "$recovered" == "false" ]]; then
          echo "[FAILED] $file_line ($detected_algo)"
          failures=$((failures + 1))
        fi
      fi
    fi

  done 3<"$sumfile"

  if [[ "$failures" -gt 0 ]]; then return "$EX_INTEGRITY_FAIL"; fi
  if [[ "$verified_count" -eq 0 ]]; then return "$EX_OPERATIONAL_ERROR"; fi
  return "$EX_SUCCESS"
}

# coreutils::calculate
coreutils::calculate() {
  local algo="$1"
  local file="$2"
  local cmd
  cmd=$(__resolve_cmd "$algo")

  if [[ ! -f "$file" ]]; then
    return "$EX_OPERATIONAL_ERROR"
  fi

  local args=()
  if [[ "$algo" =~ ^blake2-([0-9]+)$ ]]; then
    local bits="${BASH_REMATCH[1]}"
    args+=("-l" "$bits")
  fi

  if "$cmd" "${args[@]}" "$file"; then
    return "$EX_SUCCESS"
  else
    return "$EX_OPERATIONAL_ERROR"
  fi
}
