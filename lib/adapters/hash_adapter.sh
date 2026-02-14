#!/usr/bin/env bash
#
# lib/adapters/hash_adapter.sh
# Hash Adapter: Interface for cryptographic hash operations.
#
# Responsibility: Abstract the execution of underlying system binaries
# (coreutils, shasum, b2sum) to calculate and verify file checksums.
# Handles logic for batch verification, fallback strategies, and context detection.

# ----------------------------------------------------------------------
# Internal Helper Functions
# ----------------------------------------------------------------------

# Internal: Executes standard binaries (native strategy).
#
# $1 - cmd_bin       - The binary to execute (e.g., sha256sum).
# $2 - ref_name      - Name of the array variable containing arguments.
# $3 - file          - Target file.
# $4 - expected_hash - (Optional) Hash for verification.
#
# Returns the exit code of the binary.
__exec_native() {
  local cmd_bin="$1"
  local ref_name="$2"
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

# Internal: Executes the shasum Perl script (macOS/*BSD strategy).
#
# $1 - algo          - Algorithm name (e.g., sha256).
# $2 - file          - Target file.
# $3 - expected_hash - (Optional) Hash for verification.
#
# Returns the exit code of the binary.
__exec_shasum() {
  local algo="$1"
  local file="$2"
  local expected_hash="${3:-}"

  local bits="${algo#sha}"
  local args=("-a" "$bits")

  if [[ -n "$expected_hash" ]]; then
    args+=("-c" "-")
    echo "${expected_hash}  ${file}" | shasum "${args[@]}" >/dev/null 2>&1
    return $?
  else
    shasum "${args[@]}" "$file"
    return $?
  fi
}

# Internal: Resolves SHA algorithm name by hash length.
#
# $1 - len - Length of the hash string.
#
# Returns the algorithm name to stdout.
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

# ----------------------------------------------------------------------
# Public Functions
# ----------------------------------------------------------------------

# Public: Determines the expected byte/char length of a hash algorithm.
#
# $1 - algo - The algorithm name.
#
# Returns the length integer to stdout.
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

# Public: Suggests a fallback algorithm if the primary one fails.
# Useful for resolving ambiguity between SHA and BLAKE families.
#
# $1 - algo - The primary algorithm.
#
# Returns the fallback algorithm name to stdout.
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

# Public: Verifies a single file against a specific hash.
# Handles normalization and binary selection (Native vs Perl).
#
# $1 - raw_algo      - The algorithm name.
# $2 - file          - The file to verify.
# $3 - expected_hash - The expected checksum.
#
# Returns EX_SUCCESS or EX_INTEGRITY_FAIL/EX_OPERATIONAL_ERROR.
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

  # B) MD5 (Always Native)
  elif [[ "$algo" == "md5" ]]; then
    local cmd="md5sum"
    local args=("-c" "-")
    if __exec_native "$cmd" args "$file" "$expected_hash"; then return "$EX_SUCCESS"; else return "$EX_INTEGRITY_FAIL"; fi

  # C) SHA Family (Native -> Perl Fallback)
  elif [[ "$algo" == "sha"* ]]; then
    if [[ -z "$CHECKIT_FORCE_PERL" ]] && command -v "${algo}sum" >/dev/null; then
      local cmd="${algo}sum"
      local args=("-c" "-")
      if __exec_native "$cmd" args "$file" "$expected_hash"; then return "$EX_SUCCESS"; else return "$EX_INTEGRITY_FAIL"; fi

    elif command -v "shasum" >/dev/null; then
      if __exec_shasum "$algo" "$file" "$expected_hash"; then return "$EX_SUCCESS"; else return "$EX_INTEGRITY_FAIL"; fi

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

# Public: Calculates the hash of a file.
#
# $1 - algo - The algorithm name.
# $2 - file - The file to hash.
#
# Returns EX_SUCCESS or EX_OPERATIONAL_ERROR.
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
    if [[ -z "$CHECKIT_FORCE_PERL" ]] && command -v "${algo}sum" >/dev/null; then
      local cmd="${algo}sum"
      local args=()
      if __exec_native "$cmd" args "$file"; then return "$EX_SUCCESS"; else return "$EX_OPERATIONAL_ERROR"; fi

    elif command -v "shasum" >/dev/null; then
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

# Public: Iterates through a checksum file and verifies all entries.
# Handles logic for missing files, skipping invalid lines, and context detection.
#
# $1 - forced_cli_algo - Override algorithm (or "auto").
# $2 - sumfile         - Path to the checksums file.
#
# Returns EX_SUCCESS if all files pass, EX_INTEGRITY_FAIL otherwise.
hash_adapter::check_list() {
  local forced_cli_algo="$1"
  local sumfile="$2"

  if [[ ! -f "$sumfile" ]]; then return "$EX_OPERATIONAL_ERROR"; fi

  # --- Counters ---
  local cnt_ok=0
  local cnt_failed=0    # Checksum mismatches
  local cnt_missing=0   # File not found
  local cnt_skipped=0   # Algorithm mismatches / Skips
  local cnt_bad_lines=0 # Parsing errors
  local cnt_signed=0    # Verified GPG signatures
  local cnt_bad_sig=0   # Failed GPG signatures

  # --- Context Detection ---
  local context_algo=""

  # 1. Content-Hash (Strong Context)
  if meta_algo=$(core::identify_from_file "$sumfile"); then
    context_algo="$meta_algo"
  fi

  # 2. Filename (Medium Context)
  # Bash 5 Optimization: Use parameter expansion instead of basename/tr
  if [[ -z "$context_algo" ]]; then
    local fname_base="${sumfile##*/}"
    local fname_lower="${fname_base,,}"

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

      # Bash 5 Optimization: Native trim instead of sed
      local clean_line="${line#"${line%%[![:space:]]*}"}"
      clean_line="${clean_line%"${clean_line##*[![:space:]]}"}"

      # Regex: start with hex, spaces, optional '*', rest is filename
      if [[ "$clean_line" =~ ^([a-fA-F0-9]+)[[:space:]]+[\*]?(.+)$ ]]; then
        local raw_hash="${BASH_REMATCH[1]}"
        local raw_file="${BASH_REMATCH[2]}"
        parsed="unknown|$raw_hash|$raw_file"
      else
        # Bash 5 Optimization: Remove spaces natively
        if [[ "$line" != \#* && -n "${line//[[:space:]]/}" ]]; then
          cnt_bad_lines=$((cnt_bad_lines + 1))
        fi
        continue
      fi
    fi

    # Bash 5 Optimization: Native string splitting instead of cut
    local parsed_algo="${parsed%%|*}"
    local rest="${parsed#*|}"
    local hash_line="${rest%%|*}"
    local file_line="${rest#*|}"

    # --- Missing File Check ---
    if [[ ! -f "$file_line" ]]; then
      if [[ "$__CLI_IGNORE_MISSING" == "true" ]]; then continue; fi
      ui::log_file_status "$ST_MISSING" "$file_line"
      cnt_missing=$((cnt_missing + 1))
      continue
    fi

    # --- Algorithm Selection ---
    local target_algo=""
    local allow_fallback=true

    # 1. CLI Override
    if [[ "$forced_cli_algo" != "auto" ]]; then
      target_algo="$forced_cli_algo"
      allow_fallback=false

    # 2. BSD Tags
    elif [[ "$line" =~ ^[A-Za-z0-9-]+[[:space:]]*\(.+\)[[:space:]]*=[[:space:]]*[a-fA-F0-9]+ ]]; then
      target_algo="$parsed_algo"
      allow_fallback=false

    # 3. Strict Context
    elif [[ -n "$context_algo" ]]; then
      if [[ "$context_algo" == "sha_family" ]]; then
        target_algo=$(__get_sha_by_length "${#hash_line}")
        if [[ -z "$target_algo" ]]; then
          ui::log_file_status "$ST_SKIP" "$file_line" "Not a SHA hash"
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
          ui::log_file_status "$ST_SKIP" "$file_line" "Format mismatch: expected $context_algo"
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

    # --- Verification ---
    if [[ -z "$target_algo" ]]; then continue; fi

    local expected_len
    expected_len=$(hash_adapter::get_algo_length "$target_algo")
    if [[ "$expected_len" -gt 0 && "${#hash_line}" -ne "$expected_len" ]]; then
      ui::log_file_status "$ST_FAIL" "$file_line" "Format mismatch"
      cnt_failed=$((cnt_failed + 1))
      continue
    fi

    # Verification Loop (Target -> Fallback)
    local verify_result=false
    local final_algo="$target_algo"

    if hash_adapter::verify "$target_algo" "$file_line" "$hash_line"; then
      verify_result=true
    else
      if [[ "$allow_fallback" == "true" ]]; then
        local fallback
        fallback=$(hash_adapter::get_fallback_algo "$target_algo")
        if [[ -n "$fallback" ]]; then
          if hash_adapter::verify "$fallback" "$file_line" "$hash_line"; then
            verify_result=true
            final_algo=$fallback
          fi
        fi
      fi
    fi

    if [[ "$verify_result" == "true" ]]; then
      cnt_ok=$((cnt_ok + 1))

      # --- GPG Target Signature Check ---
      local extra_status=""
      local gpg_out=""
      local gpg_code=0

      if gpg::detect_signature "$file_line"; then
        gpg_out=$(gpg::verify_detached "$file_line")
        gpg_code=$?

        if [[ "$gpg_code" -eq "$EX_SUCCESS" ]]; then
          extra_status="$ST_SIGNED"
          cnt_signed=$((cnt_signed + 1))
        else
          # --- Strict Mode ---
          if [[ "$__CLI_STRICT_SECURITY" == "true" ]]; then
            ui::log_file_status "$ST_OK" "$file_line" "$final_algo" "$ST_BAD_SIG"
            if [[ "$gpg_code" -eq "$EX_SECURITY_FAIL" ]]; then
              ui::log_critical "$(ui::get_msg 'err_sig_bad_strict')"
            else
              ui::log_critical "$(ui::get_msg 'err_sig_missing_strict')"
            fi
            if [[ -n "$gpg_out" ]]; then
              echo "$gpg_out" >&2
            fi
            return "$EX_SECURITY_FAIL"
          fi
          extra_status="$ST_BAD_SIG"
          cnt_bad_sig=$((cnt_bad_sig + 1))
        fi
      fi
      ui::log_file_status "$ST_OK" "$file_line" "$final_algo" "$extra_status"
    else
      cnt_failed=$((cnt_failed + 1))
      ui::log_file_status "$ST_FAIL" "$file_line" "$final_algo"
    fi

  done 3<"$sumfile"

  # --- Final Summary Report ---
  if [[ "$__CLI_STATUS" != "true" ]]; then
    ui::log_report_summary \
      "$cnt_ok" \
      "$cnt_failed" \
      "$cnt_missing" \
      "$cnt_skipped" \
      "$cnt_bad_sig" \
      "$cnt_signed" \
      "$cnt_bad_lines"
  fi

  # --- Exit Code Determination ---
  if [[ "$__CLI_STRICT" == "true" ]]; then
    if [[ "$cnt_bad_lines" -gt 0 || "$cnt_skipped" -gt 0 ]]; then
      return "$EX_INTEGRITY_FAIL"
    fi
  fi

  if [[ "$cnt_missing" -gt 0 || "$cnt_failed" -gt 0 || "$cnt_bad_sig" -gt 0 ]]; then
    return "$EX_INTEGRITY_FAIL"
  fi

  return "$EX_SUCCESS"
}
