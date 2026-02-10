#!/usr/bin/env bash

# --- STRATEGY: NATIVE (GNU Coreutils / Busybox) ---
# Execute standard binaries such as sha256sum, md5sum, b2sum.
__exec_native() {
  local cmd_bin="$1"
  local ref_name="$2" # The caller's array variable name (e.g., "args")
  local file="$3"
  local expected_hash="${4:-}"

  local -n native_args=$ref_name

  if [[ -n "$expected_hash" ]]; then
    # Verify Mode
    echo "${expected_hash}  ${file}" | "$cmd_bin" "${native_args[@]}" >/dev/null 2>&1
    return $?
  else
    # Calculate Mode
    "$cmd_bin" "${native_args[@]}" "$file"
    return $?
  fi
}

# --- STRATEGY: PERL (shasum script) ---
# Run the shasum script (common on macOS/*BSD) emulating coreutils.
__exec_shasum() {
  local algo="$1"
  local file="$2"
  local expected_hash="${3:-}"

  local bits="${algo#sha}"

  local args=("-a" "$bits")

  if [[ -n "$expected_hash" ]]; then
    # Verify Mode (-c - lee de stdin)
    args+=("-c" "-")
    echo "${expected_hash}  ${file}" | shasum "${args[@]}" >/dev/null 2>&1
    return $?
  else
    # Calculate Mode
    shasum "${args[@]}" "$file"
    return $?
  fi
}

# --- INTERNAL HELPER: Resolve SHA version by length ---
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

# --- PUBLIC HELPER: Get Algo Length ---
hash_adapter::get_algo_length() {
  local algo="$1"

  if [[ "$algo" =~ ^blake2-([0-9]+)$ ]]; then
    local bits="${BASH_REMATCH[1]}"
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

# --- PUBLIC HELPER: Fallback Resolver ---
hash_adapter::get_fallback_algo() {
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

# --- MAIN: VERIFY ---
hash_adapter::verify() {
  local raw_algo="$1"
  local file="$2"
  local expected_hash="$3"
  local algo="$raw_algo"

  if [[ ! -f "$file" ]]; then return "$EX_OPERATIONAL_ERROR"; fi

  # 1. Normalization
  if [[ "$algo" =~ ^b2-?([0-9]+)$ ]]; then algo="blake2-${BASH_REMATCH[1]}"; fi
  if [[ "$algo" =~ ^blake2b?([0-9]+)$ ]]; then algo="blake2-${BASH_REMATCH[1]}"; fi

  # 2. Length Validation
  local expected_len
  expected_len=$(hash_adapter::get_algo_length "$algo")
  if [[ "$expected_len" -gt 0 && "${#expected_hash}" -ne "$expected_len" ]]; then
    return "$EX_INTEGRITY_FAIL"
  fi

  # 3. Strategy Selection

  # A) Blake Family (Always Native)
  if [[ "$algo" == "blake2"* ]]; then
    local cmd="b2sum"
    local args=("-c" "-")
    if [[ "$algo" =~ ^blake2-([0-9]+)$ ]]; then args=("-l" "${BASH_REMATCH[1]}" "-c" "-"); fi

    if __exec_native "$cmd" args "$file" "$expected_hash"; then return "$EX_SUCCESS"; else return "$EX_INTEGRITY_FAIL"; fi

  # B) MD5 (Always Native - shasum doesn't support it)
  elif [[ "$algo" == "md5" ]]; then
    local cmd="md5sum"
    local args=("-c" "-")
    if __exec_native "$cmd" args "$file" "$expected_hash"; then return "$EX_SUCCESS"; else return "$EX_INTEGRITY_FAIL"; fi

  # C) SHA Family (Try Native -> Fallback Perl)
  elif [[ "$algo" == "sha"* ]]; then
    # Try Native
    if [[ -z "$CHECKIT_FORCE_PERL" ]] && type -t "${algo}sum" >/dev/null; then
      local cmd="${algo}sum"
      local args=("-c" "-")
      if __exec_native "$cmd" args "$file" "$expected_hash"; then return "$EX_SUCCESS"; else return "$EX_INTEGRITY_FAIL"; fi

    # Try Shasum (Perl)
    elif type -t "shasum" >/dev/null; then
      if __exec_shasum "$algo" "$file" "$expected_hash"; then return "$EX_SUCCESS"; else return "$EX_INTEGRITY_FAIL"; fi

    # Fail
    else
      # Try native explicitly to force command-not-found error visible if desired
      local cmd="${algo}sum"
      local args=("-c" "-")
      __exec_native "$cmd" args "$file" "$expected_hash"
      return "$EX_INTEGRITY_FAIL"
    fi

  else
    # Unknown algo, try blindly as native binary
    local cmd="${algo}sum"
    local args=("-c" "-")
    if __exec_native "$cmd" args "$file" "$expected_hash"; then return "$EX_SUCCESS"; else return "$EX_INTEGRITY_FAIL"; fi
  fi
}

# --- MAIN: CALCULATE ---
hash_adapter::calculate() {
  local algo="$1"
  local file="$2"

  if [[ ! -f "$file" ]]; then return "$EX_OPERATIONAL_ERROR"; fi

  # A) Blake Family
  if [[ "$algo" == "blake2"* ]]; then
    local cmd="b2sum"
    local args=()
    if [[ "$algo" =~ ^blake2-([0-9]+)$ ]]; then args=("-l" "${BASH_REMATCH[1]}"); fi

    if __exec_native "$cmd" args "$file"; then return "$EX_SUCCESS"; else return "$EX_OPERATIONAL_ERROR"; fi

  # B) MD5
  elif [[ "$algo" == "md5" ]]; then
    local cmd="md5sum"
    local args=()
    if __exec_native "$cmd" args "$file"; then return "$EX_SUCCESS"; else return "$EX_OPERATIONAL_ERROR"; fi

  # C) SHA Family
  elif [[ "$algo" == "sha"* ]]; then
    if [[ -z "$CHECKIT_FORCE_PERL" ]] && type -t "${algo}sum" >/dev/null; then
      local cmd="${algo}sum"
      local args=()
      if __exec_native "$cmd" args "$file"; then return "$EX_SUCCESS"; else return "$EX_OPERATIONAL_ERROR"; fi

    elif type -t "shasum" >/dev/null; then
      if __exec_shasum "$algo" "$file"; then return "$EX_SUCCESS"; else return "$EX_OPERATIONAL_ERROR"; fi

    else
      return "$EX_OPERATIONAL_ERROR"
    fi

  else
    local cmd="${algo}sum"
    local args=()
    if __exec_native "$cmd" args "$file"; then return "$EX_SUCCESS"; else return "$EX_OPERATIONAL_ERROR"; fi
  fi
}

# hash_adapter::check_list
hash_adapter::check_list() {
  local forced_cli_algo="$1"
  local sumfile="$2"

  if [[ ! -f "$sumfile" ]]; then return "$EX_OPERATIONAL_ERROR"; fi

  # --- COUNTERS INITIALIZATION ---
  local cnt_ok=0
  local cnt_failed=0    # Checksum mismatches
  local cnt_missing=0   # File not found
  local cnt_skipped=0   # Algorithm mismatches / Skips
  local cnt_bad_lines=0 # Parsing errors
  local cnt_signed=0    # Verified GPG signatures
  local cnt_bad_sig=0   # Failed GPG signatures

  # Internal callback for success
  __on_success() {
    local f_path="$1"
    local f_algo="$2"
    local extra_info=""

    # Check GPG signature if available
    if type -t gpg::verify_target >/dev/null; then
      if gpg::verify_target "$f_path"; then
        extra_info="${C_GREENH}${SYMBOL_SIGNED}${C_R}"
        cnt_signed=$((cnt_signed + 1))
      elif [[ $? -eq 3 ]]; then
        extra_info="${C_REDH}${SYMBOL_BAD}${C_R}"
        cnt_bad_sig=$((cnt_bad_sig + 1))
      fi
    fi

    if [[ "$__CLI_QUIET" == "true" || "$__CLI_STATUS" == "true" ]]; then
      return
    fi
    ui::log_success "$f_path ($f_algo)" "${extra_info}"
  }

  # Internal callback for failure
  __on_failure() {
    local f_file="$1"
    local f_algo="$2"
    if [[ "$__CLI_STATUS" == "true" ]]; then return; fi
    ui::log_failed "$f_file ($f_algo)"
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

  # shellcheck disable=SC2094
  while IFS= read -r line <&3 || [[ -n "$line" ]]; do
    local parsed

    # Strict parsing (detects known algorithms)
    if ! parsed=$(core::parse_line "$line" "$sumfile"); then
      local clean_line
      clean_line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

      # Regex: start with hex, spaces, optional '*', rest is filename
      if [[ "$clean_line" =~ ^([a-fA-F0-9]+)[[:space:]]+[\*]?(.+)$ ]]; then
        local raw_hash="${BASH_REMATCH[1]}"
        local raw_file="${BASH_REMATCH[2]}"
        parsed="unknown|$raw_hash|$raw_file"
      else
        if [[ "$line" != \#* && -n "$(echo "$line" | tr -d '[:space:]')" ]]; then
          cnt_bad_lines=$((cnt_bad_lines + 1))
        fi
        continue
      fi
    fi

    local parsed_algo
    local hash_line
    local file_line
    parsed_algo=$(echo "$parsed" | cut -d'|' -f1)
    hash_line=$(echo "$parsed" | cut -d'|' -f2)
    file_line=$(echo "$parsed" | cut -d'|' -f3)

    # --- MISSING FILE CHECK ---
    if [[ ! -f "$file_line" ]]; then
      if [[ "$__CLI_IGNORE_MISSING" == "true" ]]; then continue; fi
      ui::log_missing "$file_line" >&2
      cnt_missing=$((cnt_missing + 1))
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

    # 3. Strict Context
    elif [[ -n "$context_algo" ]]; then
      if [[ "$context_algo" == "sha_family" ]]; then
        target_algo=$(__get_sha_by_length "${#hash_line}")
        if [[ -z "$target_algo" ]]; then
          ui::log_skipped "$file_line ${C_MSG2}(Not a SHA hash)${C_R}"
          cnt_skipped=$((cnt_skipped + 1))
          continue
        fi
        allow_fallback=false

      elif [[ "$context_algo" == "blake_family" ]]; then
        if [[ "$parsed_algo" == "blake"* ]] || [[ "$parsed_algo" == "b2"* ]]; then
          target_algo="$parsed_algo"
        else
          target_algo=$(hash_adapter::get_fallback_algo "$parsed_algo")
        fi
        allow_fallback=false

      else
        local ctx_len
        ctx_len=$(hash_adapter::get_algo_length "$context_algo")
        if [[ "${#hash_line}" -ne "$ctx_len" ]]; then
          ui::log_skipped "$file_line (Format mismatch: expected $context_algo)"
          cnt_skipped=$((cnt_skipped + 1))
          continue
        fi
        target_algo="$context_algo"
        allow_fallback=false
      fi

    # 4. Mixed / Neutral Mode
    else
      target_algo="$parsed_algo"
    fi

    # --- VERIFICATION ---
    if [[ -z "$target_algo" ]]; then continue; fi

    local expected_len
    expected_len=$(hash_adapter::get_algo_length "$target_algo")
    if [[ "$expected_len" -gt 0 && "${#hash_line}" -ne "$expected_len" ]]; then
      ui::log_failed "$file_line (Format mismatch)"
      cnt_failed=$((cnt_failed + 1))
      continue
    fi

    if hash_adapter::verify "$target_algo" "$file_line" "$hash_line"; then
      __on_success "$file_line" "$target_algo"
      cnt_ok=$((cnt_ok + 1))
    else
      local recovered=false
      if [[ "$allow_fallback" == "true" ]]; then
        local fallback
        fallback=$(hash_adapter::get_fallback_algo "$target_algo")
        if [[ -n "$fallback" ]]; then
          if hash_adapter::verify "$fallback" "$file_line" "$hash_line"; then
            __on_success "$file_line" "$fallback"
            cnt_ok=$((cnt_ok + 1))
            recovered=true
          fi
        fi
      fi

      if [[ "$recovered" == "false" ]]; then
        __on_failure "$file_line" "$target_algo"
        cnt_failed=$((cnt_failed + 1))
      fi
    fi

  done 3<"$sumfile"

  # --- FINAL SUMMARY REPORT ---
  # Only print summary if --status is NOT active
  if [[ "$__CLI_STATUS" != "true" ]]; then

    # A. Report formatting warnings
    if [[ "$cnt_bad_lines" -gt 0 ]]; then
      local msg="lines are"
      [[ "$cnt_bad_lines" -eq 1 ]] && msg="line is"
      if [[ "$__CLI_WARN" == "true" || "$__CLI_STRICT" == "true" ]]; then
        ui::log_report $cnt_bad_lines " $msg improperly formatted"
      fi
    fi

    # B. Report skipped files (Context mismatch)
    if [[ "$cnt_skipped" -gt 0 ]]; then
      local msg="files were"
      [[ "$cnt_skipped" -eq 1 ]] && msg="file was"
      ui::log_report $cnt_skipped " $msg skipped due to context mismatch"
    fi

    # C. Report missing files
    if [[ "$cnt_missing" -gt 0 && "$__CLI_IGNORE_MISSING" != "true" ]]; then
      local msg="listed files"
      [[ "$cnt_missing" -eq 1 ]] && msg="listed file"
      ui::log_report $cnt_missing " $msg could not be read"
    fi

    # D. Report failed checksums
    if [[ "$cnt_failed" -gt 0 ]]; then
      local msg="computed checksums"
      [[ "$cnt_failed" -eq 1 ]] && msg="computed checksum"
      ui::log_report ${cnt_failed} " $msg did NOT match"
    fi

    # E. Report bad signatures (GPG)
    if [[ "$cnt_bad_sig" -gt 0 ]]; then
      local msg="signatures"
      [[ "$cnt_bad_sig" -eq 1 ]] && msg="signature"
      ui::log_report $cnt_bad_sig " $msg failed verification"
    fi

    # F. Report success stats (Optional but requested)
    # Only if NOT quiet, to give positive feedback
    if [[ "$__CLI_QUIET" != "true" && "$cnt_ok" -gt 0 ]]; then
      # Build a summary string
      local summary="checkit: ${C_MSG2}Verified${C_R} $cnt_ok ${C_MSG2}files${C_R}"
      if [[ "$cnt_signed" -gt 0 ]]; then
        summary="$summary ($cnt_signed ${C_GREEN}signed${C_R})"
      fi
      echo -e "$summary." >&2
    fi
  fi

  # --- EXIT CODE DETERMINATION ---
  # Strict Mode: Any warning (bad format, skips) is fatal
  if [[ "$__CLI_STRICT" == "true" ]]; then
    if [[ "$cnt_bad_lines" -gt 0 || "$cnt_skipped" -gt 0 ]]; then
      return "$EX_INTEGRITY_FAIL"
    fi
  fi

  # Standard Failures
  if [[ "$cnt_missing" -gt 0 || "$cnt_failed" -gt 0 || "$cnt_bad_sig" -gt 0 ]]; then
    return "$EX_INTEGRITY_FAIL"
  fi

  return "$EX_SUCCESS"
}
