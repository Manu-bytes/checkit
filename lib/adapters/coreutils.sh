#!/usr/bin/env bash

# Helper: Map algorithm string to corresponding binary.
__resolve_cmd() {
  local algo="$1"
  if [[ "$algo" == "blake2"* ]] || [[ "$algo" == "b2"* ]]; then
    echo "b2sum"
  else
    echo "${algo}sum"
  fi
}

# Helper: Get fallback algorithm for blind ambiguity.
# Used externally by algorithm_chooser logic.
coreutils::get_fallback_algo() {
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
# Made PUBLIC (coreutils::) so verify can use it for pre-validation.
coreutils::get_algo_length() {
  local algo="$1"

  # Check for explicit blake2-SIZE format first
  if [[ "$algo" =~ ^blake2-([0-9]+)$ ]]; then
    local bits="${BASH_REMATCH[1]}"
    # Length in hex chars = bits / 4
    echo $((bits / 4))
    return
  fi

  case "$algo" in
  md5 | blake2-128) echo 32 ;;
  sha1 | blake2-160) echo 40 ;;
  sha224 | blake2-224) echo 56 ;;
  sha256 | blake2-256) echo 64 ;;
  sha384 | blake2-384) echo 96 ;;
  sha512 | blake2 | b2 | blake2b | blake2-512) echo 128 ;;
  *) echo 0 ;;
  esac
}

# Helper: Resolve SHA version by length for "shasums" generic files.
__get_sha_by_length() {
  local len="$1"
  case "$len" in
  40) echo "sha1" ;;
  56) echo "sha224" ;;
  64) echo "sha256" ;;
  96) echo "sha384" ;;
  128) echo "sha512" ;;
  *) echo "" ;;
  esac
}

# coreutils::verify
coreutils::verify() {
  local raw_algo="$1"
  local file="$2"
  local expected_hash="$3"
  local algo="$raw_algo"

  if [[ ! -f "$file" ]]; then return "$EX_OPERATIONAL_ERROR"; fi

  # --- 0. ALGORITHM NORMALIZATION ---
  # Standardize "b2", "b2-", "blake2b", etc. to "blake2-SIZE" or "blake2"

  # 1. Normalize prefixes: b2-XXX -> blake2-XXX
  if [[ "$algo" =~ ^b2-?([0-9]+)$ ]]; then
    algo="blake2-${BASH_REMATCH[1]}"
  fi

  # 2. Normalize concatenated suffix: blake2b256 -> blake2-256
  if [[ "$algo" =~ ^blake2b?([0-9]+)$ ]]; then
    algo="blake2-${BASH_REMATCH[1]}"
  fi

  # --- 1. STRICT LENGTH VALIDATION ---
  local expected_len
  expected_len=$(coreutils::get_algo_length "$algo")

  if [[ "$expected_len" -gt 0 ]]; then
    if [[ "${#expected_hash}" -ne "$expected_len" ]]; then
      return "$EX_INTEGRITY_FAIL"
    fi
  fi

  # --- 2. EXECUTION ---
  local cmd
  cmd=$(__resolve_cmd "$algo")

  local args=("-c" "-")

  # Now checking the NORMALIZED algo variable
  if [[ "$algo" =~ ^blake2-([0-9]+)$ ]]; then
    local bits="${BASH_REMATCH[1]}"
    args=("-l" "$bits" "-c" "-")
  fi

  # Pass original hash and file to the binary
  if echo "${expected_hash}  ${file}" | "$cmd" "${args[@]}" >/dev/null 2>&1; then
    return "$EX_SUCCESS"
  else
    return "$EX_INTEGRITY_FAIL"
  fi
}

# coreutils::check_list
coreutils::check_list() {
  local forced_cli_algo="$1"
  local sumfile="$2"

  if [[ ! -f "$sumfile" ]]; then return "$EX_OPERATIONAL_ERROR"; fi

  __on_success() {
    local f_path="$1"
    local f_algo="$2"
    local extra_info=""

    if [[ "$__CLI_QUIET" == "true" || "$__CLI_STATUS" == "true" ]]; then
      return
    fi

    if type -t gpg::verify_target >/dev/null; then
      if gpg::verify_target "$f_path"; then
        extra_info=" + [SIGNED]"
      elif [[ $? -eq 3 ]]; then
        extra_info=" + [BAD SIG]"
      fi
    fi

    echo "[OK] $f_path ($f_algo)${extra_info}"
  }

  __on_failure() {
    local f_file="$1"
    local f_algo="$2"
    if [[ "$__CLI_STATUS" == "true" ]]; then return; fi
    echo "[FAILED] $f_file ($f_algo)"
  }

  # --- CONTEXT DETECTION ---
  local context_algo=""

  # 1. Content-Hash (Strong Context)
  if meta_algo=$(core::identify_from_file "$sumfile"); then
    context_algo="$meta_algo"
  fi

  # 2. Filename (Medium Context)
  if [[ -z "$context_algo" ]]; then
    local fname_lower
    fname_lower=$(basename "$sumfile" | tr '[:upper:]' '[:lower:]')

    if [[ "$fname_lower" =~ ^(md5|sha1|sha224|sha256|sha384|sha512) ]]; then
      context_algo="${BASH_REMATCH[1]}"
    elif [[ "$fname_lower" =~ (b2|blake2) ]]; then
      context_algo="blake_family"
    elif [[ "$fname_lower" =~ sha ]]; then
      context_algo="sha_family"
    fi
  fi

  local failures=0
  local verified_count=0
  local bad_lines=0

  # shellcheck disable=SC2094
  while IFS= read -r line <&3 || [[ -n "$line" ]]; do
    local parsed
    if ! parsed=$(core::parse_line "$line" "$sumfile"); then
      if [[ "$line" != \#* && -n "$(echo "$line" | tr -d '[:space:]')" ]]; then
        bad_lines=$((bad_lines + 1))
      fi
      continue
    fi

    local parsed_algo
    local hash_line
    local file_line
    parsed_algo=$(echo "$parsed" | cut -d'|' -f1)
    hash_line=$(echo "$parsed" | cut -d'|' -f2)
    file_line=$(echo "$parsed" | cut -d'|' -f3)

    if [[ ! -f "$file_line" ]]; then
      if [[ "$__CLI_IGNORE_MISSING" == "true" ]]; then continue; fi
      echo "[MISSING] $file_line" >&2
      failures=$((failures + 1))
      continue
    fi

    # --- ALGORITHM SELECTION ---
    local target_algo=""
    local allow_fallback=true

    # 1. CLI Override (Override Total)
    if [[ "$forced_cli_algo" != "auto" ]]; then
      target_algo="$forced_cli_algo"
      allow_fallback=false

    # 2. BSD Tags (Override Contextual)
    elif [[ "$line" =~ ^[A-Za-z0-9-]+[[:space:]]*\(.+\)[[:space:]]*=[[:space:]]*[a-fA-F0-9]+ ]]; then
      target_algo="$parsed_algo"
      allow_fallback=false

    # 3. Strict context (e.g., SHA256SUMS or content-hash)
    elif [[ -n "$context_algo" ]]; then
      if [[ "$context_algo" == "sha_family" ]]; then
        target_algo=$(__get_sha_by_length "${#hash_line}")
        if [[ -z "$target_algo" ]]; then
          echo "[SKIPPED] $file_line (Not a SHA hash)"
          continue
        fi
        allow_fallback=false
      elif [[ "$context_algo" == "blake_family" ]]; then
        if [[ "$parsed_algo" == "blake"* ]] || [[ "$parsed_algo" == "b2"* ]]; then
          target_algo="$parsed_algo"
        else
          target_algo=$(coreutils::get_fallback_algo "$parsed_algo")
        fi
        allow_fallback=false
      else

        # Case: Specific algorithm (md5, sha256, blake2-256)
        local ctx_len
        ctx_len=$(coreutils::get_algo_length "$context_algo")
        if [[ "${#hash_line}" -ne "$ctx_len" ]]; then
          echo "[SKIPPED] $file_line (Format mismatch: expected $context_algo)"
          continue
        fi
        target_algo="$context_algo"
        allow_fallback=false
      fi

    # 4. Mixed / Neutral mode
    else
      target_algo="$parsed_algo"
    fi

    # --- VERIFICATION ---
    if [[ -z "$target_algo" ]]; then continue; fi
    local expected_len
    expected_len=$(coreutils::get_algo_length "$target_algo")
    if [[ "$expected_len" -gt 0 && "${#hash_line}" -ne "$expected_len" ]]; then
      echo "[FAILED] $file_line (Format mismatch)"
      failures=$((failures + 1))
      continue
    fi

    if coreutils::verify "$target_algo" "$file_line" "$hash_line"; then
      __on_success "$file_line" "$target_algo"
      verified_count=$((verified_count + 1))
    else
      local recovered=false
      if [[ "$allow_fallback" == "true" ]]; then
        local fallback
        fallback=$(coreutils::get_fallback_algo "$target_algo")
        if [[ -n "$fallback" ]]; then
          if coreutils::verify "$fallback" "$file_line" "$hash_line"; then
            __on_success "$file_line" "$fallback"
            verified_count=$((verified_count + 1))
            recovered=true
          fi
        fi
      fi

      if [[ "$recovered" == "false" ]]; then
        __on_failure "$file_line" "$target_algo"
        failures=$((failures + 1))
      fi
    fi

  done 3<"$sumfile"

  if [[ "$bad_lines" -gt 0 ]]; then
    if [[ "$__CLI_WARN" == "true" || "$__CLI_STRICT" == "true" ]]; then
      echo "checkit: WARNING: $bad_lines line is improperly formatted" >&2
    fi
  fi
  if [[ "$failures" -gt 0 ]]; then return "$EX_INTEGRITY_FAIL"; fi
  if [[ "$bad_lines" -gt 0 && "$__CLI_STRICT" == "true" ]]; then return "$EX_INTEGRITY_FAIL"; fi
  if [[ "$verified_count" -eq 0 ]]; then
    if [[ "$__CLI_IGNORE_MISSING" == "true" ]]; then return "$EX_SUCCESS"; fi
    return "$EX_OPERATIONAL_ERROR"
  fi
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
