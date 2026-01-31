#!/usr/bin/env bash

# Helper: internal to search for disconnected signatures
__gpg_find_detached_sig() {
  local file="$1"
  for ext in ".asc" ".sig" ".gpg"; do
    if [[ -f "${file}${ext}" ]]; then
      echo "${file}${ext}"
      return 0
    fi
  done
  return 1
}

# gpg::detect_signature
# Checks if the file contains a PGP header or if a detached signature exists.
gpg::detect_signature() {
  local file="$1"
  # Check 1: Inline Clear-Sign
  if grep -q "^-----BEGIN PGP SIGNED MESSAGE-----" "$file" 2>/dev/null; then
    return 0
  fi
  # Check 2: Detached signature presence
  if __gpg_find_detached_sig "$file" >/dev/null; then
    return 0
  fi
  return 1
}

# gpg::verify
# Verifies the signature of a file (Inline or Detached).
gpg::verify() {
  local file="$1"
  local output
  local status

  # Determine verification mode
  local detached_sig
  detached_sig=$(__gpg_find_detached_sig "$file")

  if [[ -n "$detached_sig" ]]; then
    # Mode: Detached (gpg --verify SIG DATA)
    # Redirect stderr to stdout to capture status messages
    output=$(gpg --verify "$detached_sig" "$file" 2>&1)
    status=$?
  else
    # Mode: Inline (gpg --verify FILE)
    output=$(gpg --verify "$file" 2>&1)
    status=$?
  fi

  # --- Status Analysis Logic ---

  if [[ "$status" -eq 0 ]]; then
    # GPG returns 0 for "Good signature", even if the key is untrusted/unknown.
    # The warning "This key is not certified" is printed to stderr but exit code is 0.
    return "$EX_SUCCESS"
  fi

  # Parse Failure Reason
  if echo "$output" | grep -qi "BAD signature"; then
    echo "$output"
    return "$EX_SECURITY_FAIL"
  fi

  if echo "$output" | grep -qiE "No public key|public key not found"; then
    echo "$output"
    return "$EX_OPERATIONAL_ERROR"
  fi

  # Generic error
  echo "$output"
  return "$EX_OPERATIONAL_ERROR"
}

# gpg::sign
# Signs a file (Clear-sign by default for text visibility)
gpg::sign() {
  local file="$1"
  if gpg --clearsign --output "${file}.asc" "$file"; then
    echo "${file}.asc"
    return "$EX_SUCCESS"
  fi
  return "$EX_OPERATIONAL_ERROR"
}
