#!/usr/bin/env bash

# coreutils::verify
#
# Verifies the integrity of a file using standard GNU Coreutils tools (md5sum, sha1sum, etc.).
#
# Arguments:
#   $1 - Algorithm (e.g., sha256, md5)
#   $2 - Path to the file
#   $3 - Expected hash
#
# Returns:
#   EX_SUCCESS (0) - Verification successful
#   EX_INTEGRITY_FAIL (1) - Hash does not match
#   EX_OPERATIONAL_ERROR (2) - File not found or system error

coreutils::verify() {
  local algo="$1"
  local file="$2"
  local expected_hash="$3"

  #1. Prior validation of the file
  if [[ ! -f "$file" ]]; then
    return "$EX_OPERATIONAL_ERROR"
  fi

  # 2. Build command name (e.g., sha256sum)
  local cmd="${algo}sum"

  # 3. Run verification
  # Standard format: “HASH  FILE_NAME”
  # -c : Check
  # -  : Read from STDIN
  # We redirect output to null to keep the tool silent except for errors
  if echo "${expected_hash}  ${file}" | "$cmd" -c - >/dev/null 2>&1; then
    return "$EX_SUCCESS"
  else
    return "$EX_INTEGRITY_FAIL"
  fi
}
