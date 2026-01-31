#!/usr/bin/env bats

load '../test_helper'

setup() {
  source "$PROJECT_ROOT/lib/constants.sh"

  MOCK_BIN_DIR="$BATS_TMPDIR/checkit_mocks_target_sig"
  mkdir -p "$MOCK_BIN_DIR"
  export PATH="$MOCK_BIN_DIR:$PATH"

  # --- MOCK GPG ---
  cat <<EOF >"$MOCK_BIN_DIR/gpg"
#!/bin/bash
ARGS="\$*"

# Caso: Firma de la imagen ISO (Target File)
if [[ "\$ARGS" == *"image.iso.sig"* ]]; then
  echo "gpg: Good signature from \"Arch Linux\"" >&2
  exit 0
fi

# Default fail
exit 1
EOF
  chmod +x "$MOCK_BIN_DIR/gpg"

  # --- MOCK SHA256SUM ---
  # Siempre devuelve éxito para que el foco sea la firma del target
  echo "#!/bin/bash" >"$MOCK_BIN_DIR/sha256sum"
  echo "exit 0" >>"$MOCK_BIN_DIR/sha256sum"
  chmod +x "$MOCK_BIN_DIR/sha256sum"

  # --- DATOS DE PRUEBA ---
  DATA_FILE="image.iso"
  touch "$DATA_FILE"
  touch "${DATA_FILE}.sig" # La firma desconectada

  # Un hash válido cualquiera (64 chars)
  VALID_HASH=$(printf 'a%.0s' {1..64})

  # Archivo de sumas SIN firma propia (solo contiene el hash)
  SUMFILE="checksums.txt"
  echo "$VALID_HASH  $DATA_FILE" >"$SUMFILE"
}

teardown() {
  rm -rf "$MOCK_BIN_DIR"
  rm -f "$DATA_FILE" "${DATA_FILE}.sig" "$SUMFILE"
}

@test "Target Sig: Detects and verifies signature of the target file itself" {
  # Ejecutamos checkit normal
  run "$CHECKIT_EXEC" -c "$SUMFILE"

  assert_success

  # Verificamos que reporta OK del hash
  assert_output --partial "[OK] $DATA_FILE"

  # Verificamos que reporta la firma detectada automáticamente
  assert_output --partial "[SIGNED]"
}
