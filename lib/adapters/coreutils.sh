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
coreutils::check_list() {
  local algo="$1"
  local sumfile="$2"
  local cmd
  cmd=$(__resolve_cmd "$algo")

  if [[ ! -f "$sumfile" ]]; then
    return "$EX_OPERATIONAL_ERROR"
  fi

  # Execute batch verification and suppress format warnings.
  local output
  output=$("$cmd" -c "$sumfile" 2>/dev/null)
  local status=$?

  # Reformat native output to custom "[OK] file (algo)" display.
  if [[ -n "$output" ]]; then
    echo "$output" | grep ": OK$" | sed "s/: OK$/ ($algo)/" | sed "s/^/[OK] /"
  fi

  # Map tool exit status to internal integrity codes.
  if [[ "$status" -eq 0 ]]; then
    return "$EX_SUCCESS"
  else
    return "$EX_INTEGRITY_FAIL"
  fi
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
