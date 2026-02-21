#!/usr/bin/env bash
#
# build.sh
# Checkit Bundler: Flattens the modular architecture into a single portable file.
#
# Responsibility: Reads the main entry point line-by-line and recursively
# injects source files while stripping modular boilerplate.

set -euo pipefail

# --- Configuration ---
APP_NAME="checkit"
ENTRY_POINT="bin/checkit"
DIST_DIR="dist"
OUTPUT_FILE="$DIST_DIR/$APP_NAME"
VERSION_FILE="VERSION"

# --- Metadata ---
AUTHOR="Manu-bytes"
YEAR="$(date +%Y)"
REPO_URL="https://github.com/Manu-bytes/checkit"

# 1. Read Version
if [[ -f "$VERSION_FILE" ]]; then
  VERSION_NUM=$(cat "$VERSION_FILE" | tr -d '[:space:]')
else
  VERSION_NUM="dev"
fi

echo "🚧 Building portable binary version $VERSION_NUM..."

# 2. Initialize Output Directory
mkdir -p "$DIST_DIR"
rm -f "$OUTPUT_FILE"

# 3. Write Header (Shebang + License)
{
  echo "#!/usr/bin/env bash"
  echo "#"
  echo "# ====================================================================== #"
  echo "# Checkit - File Integrity Verifier"
  echo "#"
  echo "# Copyright (C) $YEAR $AUTHOR"
  echo "#"
  echo "# This program is free software: you can redistribute it and/or modify"
  echo "# it under the terms of the GNU General Public License as published by"
  echo "# the Free Software Foundation, either version 3 of the License, or"
  echo "# (at your option) any later version."
  echo "#"
  echo "# Repository: $REPO_URL"
  echo "# Version: $VERSION_NUM"
  echo "# Built on: $(date)"
  echo "# ====================================================================== #"
  echo ""
} >"$OUTPUT_FILE"

# 4. Processing Function (Recursive Injection)
process_file() {
  local file="$1"
  local inside_version_block=0
  local header_skipped=0 # Flag to detect if we passed the file top comments

  while IFS= read -r line || [[ -n "$line" ]]; do

    # --- A. HEADER STRIPPING ---
    # Skip lines until we find actual code or an import.
    # This removes the "# bin/checkit", "# Responsibility: ...", etc.
    if [[ "$header_skipped" -eq 0 ]]; then
      # Skip shebangs (always)
      if [[ "$line" =~ ^#! ]]; then continue; fi
      # Skip comments at the very top of the file
      if [[ "$line" =~ ^# ]]; then continue; fi
      # Skip empty lines at the very top
      if [[ -z "$line" ]]; then continue; fi

      # If we hit code, mark header as done
      header_skipped=1
    fi

    # --- B. PATH BOILERPLATE STRIPPING ---
    # Logic to resolve directories is useless in a monolith.
    if [[ "$line" =~ ^BIN_DIR= ]]; then continue; fi
    if [[ "$line" =~ ^PROJECT_ROOT= ]]; then continue; fi
    if [[ "$line" =~ ^export\ PROJECT_ROOT ]]; then continue; fi
    if [[ "$line" =~ "# Resolves project root" ]]; then continue; fi

    # --- C. LINTING STRIPPING ---
    if [[ "$line" =~ "# shellcheck source=" ]]; then continue; fi

    # --- D. CONSTANTS.SH VERSION INJECTION ---
    # Detect start of version block logic
    if [[ "$line" =~ if.*\[\[.*-f.*VERSION_FILE.*\]\] ]]; then
      inside_version_block=1
      echo "CHECKIT_VERSION=\"$VERSION_NUM\"" >>"$OUTPUT_FILE"
      echo "readonly CHECKIT_VERSION" >>"$OUTPUT_FILE"
      continue
    fi

    # Consume the version block until 'fi'
    if [[ "$inside_version_block" -eq 1 ]]; then
      if [[ "$line" =~ ^[[:space:]]*fi$ ]]; then
        inside_version_block=0
      fi
      continue
    fi
    # Also skip the definition of VERSION_FILE variable
    if [[ "$line" =~ readonly\ VERSION_FILE= ]]; then continue; fi

    # --- E. SOURCE INJECTION ---
    # Detect: source "$PROJECT_ROOT/lib/..." OR . "$PROJECT_ROOT/lib/..."
    if [[ "$line" =~ (source|\.)\ \"\$PROJECT_ROOT/(.*)\" ]]; then
      local rel_path="${BASH_REMATCH[2]}"
      local full_path="$rel_path" # Assuming relative path works from root

      if [[ -f "$full_path" ]]; then
        {
          echo -e "\n"
          echo "# ================================================================================"
          echo "#  MODULE: $rel_path"
          echo "# ================================================================================"
        } >>"$OUTPUT_FILE"
        # RECURSIVE CALL
        process_file "$full_path"
      else
        echo "❌ Error: Module '$full_path' not found!" >&2
        exit 1
      fi
    else
      # --- F. OUTPUT CODE ---
      # Print the line if it wasn't filtered
      echo "$line" >>"$OUTPUT_FILE"
    fi

  done <"$file"
}

# 5. Process Main Entry Point
grep -v "^#!" "$ENTRY_POINT" >"$DIST_DIR/temp_entry"
process_file "$DIST_DIR/temp_entry"
rm "$DIST_DIR/temp_entry"

# 6. Finalize
chmod +x "$OUTPUT_FILE"

echo "✅ Build Complete!"
echo "   Output: $OUTPUT_FILE"
echo "   Size:   $(du -h "$OUTPUT_FILE" | cut -f1)"
