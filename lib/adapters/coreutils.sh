#!/usr/bin/env bash

# Map algorithm string to corresponding coreutils binary.
__resolve_cmd() {
  local algo="$1"
  # Matches blake2, blake2-256, blake2-128, etc.
  if [[ "$algo" == "blake2"* ]]; then
    echo "b2sum"
  else
    echo "${algo}sum"
  fi
}

# coreutils::verify
coreutils::verify() {
  local algo="$1"
  local file="$2"
  local expected_hash="$3"

  if [[ ! -f "$file" ]]; then
    return "$EX_OPERATIONAL_ERROR"
  fi

  local cmd
  cmd=$(__resolve_cmd "$algo")

  if echo "${expected_hash}  ${file}" | "$cmd" -c - >/dev/null 2>&1; then
    return "$EX_SUCCESS"
  else
    return "$EX_INTEGRITY_FAIL"
  fi
}

# coreutils::check_list
# Verifies a list of checksums by parsing each line individually.
# Supports mixed algorithms and non-standard formats.
#
# Arguments:
#   $1 - Ignored (Algorithm is detected per line)
#   $2 - Path to the checksum file
coreutils::check_list() {
  local _ignored_algo="$1"
  local sumfile="$2"

  if [[ ! -f "$sumfile" ]]; then
    return "$EX_OPERATIONAL_ERROR"
  fi

  local failures=0
  local verified_count=0

  # Process file line by line using FD 3 to avoid stdin conflicts
  while IFS= read -r line <&3 || [[ -n "$line" ]]; do

    # PASS THE SUMFILE AS THE SECOND ARGUMENT (HINT)
    local parsed
    if ! parsed=$(core::parse_line "$line" "$sumfile"); then
      continue
    fi

    # Extract fields (separated by pipe)
    local algo_line
    local hash_line
    local file_line

    algo_line=$(echo "$parsed" | cut -d'|' -f1)
    hash_line=$(echo "$parsed" | cut -d'|' -f2)
    file_line=$(echo "$parsed" | cut -d'|' -f3)

    # 2. Verify existence
    if [[ ! -f "$file_line" ]]; then
      # Optional: Print error or ignore.
      # For strict checking, we count it as failure.
      echo "[MISSING] $file_line"
      failures=$((failures + 1))
      continue
    fi

    # 3. Verify Integrity
    # We reuse the robust verify function
    if coreutils::verify "$algo_line" "$file_line" "$hash_line"; then
      echo "[OK] $file_line ($algo_line)"
      verified_count=$((verified_count + 1))
    else
      echo "[FAILED] $file_line ($algo_line)"
      failures=$((failures + 1))
    fi

  done 3<"$sumfile"

  # Final status logic
  if [[ "$failures" -gt 0 ]]; then
    return "$EX_INTEGRITY_FAIL"
  fi

  if [[ "$verified_count" -eq 0 ]]; then
    # No valid lines processed implies operational error (empty or bad file)
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

  # Handle bit-length argument for BLAKE2 variants.
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
