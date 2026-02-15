#!/usr/bin/env bash
#
# lib/cli/ui.sh
# UI Adapter: Handles User Output, Colors, Icons, and Help Menu
# Responsibility: Translate Internal Status Keys into human-readable, localized output.
# localized output. Decouples core logic from presentation.
#

# ----------------------------------------------------------------------
# 1. Language Detection
# ----------------------------------------------------------------------
UI_LANG="en"
if [[ "${LANG:-}" == *"es_"* || "${LC_ALL:-}" == *"es_"* ]]; then
  UI_LANG="es"
fi

# ----------------------------------------------------------------------
# 2. Message Dictionary (Portable Function)
# ----------------------------------------------------------------------

# Public: Retrieves a localized message string based on a key.
# Implements a dictionary pattern using case statements for POSIX compatibility.
#
# $1 - key - The string identifier for the message (e.g., "lbl_ok").
#
# Returns the localized string to stdout.
ui::get_msg() {
  local key="$1"

  if [[ "$UI_LANG" == "es" ]]; then
    case "$key" in
    # --- Status Labels ---
    lbl_ok) echo "OK" ;;
    lbl_fail) echo "FALLO" ;;
    lbl_miss) echo "AUSENTE" ;;
    lbl_skip) echo "OMITIDO" ;;
    lbl_signed) echo "FIRMADO" ;;
    lbl_badsig) echo "FIRMA INVÁLIDA" ;;

    # --- Report Summary ---
    rpt_prefix) echo " checkit: " ;;
    rpt_bad_fmt_sg) echo "línea tiene formato incorrecto" ;;
    rpt_bad_fmt_pl) echo "líneas tienen formato incorrecto" ;;
    rpt_skip_sg) echo "archivo omitido por contexto" ;;
    rpt_skip_pl) echo "archivos omitidos por contexto" ;;
    rpt_miss_sg) echo "archivo listado no se pudo leer" ;;
    rpt_miss_pl) echo "archivos listados no se pudieron leer" ;;
    rpt_fail_sg) echo "checksum calculado NO coincidió" ;;
    rpt_fail_pl) echo "checksums calculados NO coincidieron" ;;
    rpt_badsig_sg) echo "firma falló verificación" ;;
    rpt_badsig_pl) echo "firmas fallaron verificación" ;;
    rpt_verify) echo "Verificados" ;;
    rpt_files) echo "archivos" ;;
    rpt_signed) echo "%s firmados" ;;

    # --- Errors & Messages ---
    err_algo_id) echo "No se pudo identificar el algoritmo (longitud: %s)." ;;
    msg_sig_good) echo "Firma Verificada: Se encontró una firma válida." ;;
    err_sig_bad_strict) echo "Firma INVÁLIDA detectada. Abortando modo estricto." ;;
    warn_sig_bad) echo "Firma INVÁLIDA detectada. La integridad de la lista está comprometida." ;;
    err_sig_missing_strict) echo "Falta clave pública o error GPG. No se puede verificar en estricto." ;;
    warn_sig_missing) echo "Archivo firmado, pero falta clave pública. Procediendo con verificación de hashes." ;;
    err_sig_not_found) echo "--verify-sign solicitado pero no se halló firma en %s" ;;
    err_calc_fail) echo "Error: Fallo al calcular %s para %s" ;;
    msg_saved) echo "    Salida guardada en: %s" ;;
    msg_sig_created) echo "    Firma creada:  %s" ;;
    err_sig_detach_fail) echo "Fallo al crear firma separada GPG." ;;
    err_sig_fail) echo "Fallo al firmar con GPG." ;;
    msg_copy_ok) echo "Hashes copiados al portapapeles." ;;
    warn_arg_missing) echo "Faltan argumentos." ;;
    err_arg_fmt_invalid) echo "Formato de salida inválido '%s'. Use: text, gnu, bsd, json." ;;
    err_arg_opt_unknown) echo "Opción desconocida %s" ;;
    err_check_no_file) echo "Falta el argumento sumfile para el modo check." ;;
    err_ambiguous_mode) echo "Argumentos ambiguos. Use -c para modo check." ;;

    # --- Standard Help ---
    desc) echo "Herramienta avanzada de integridad y verificación de hashes." ;;
    usage_title) echo "Uso" ;;
    usage_1) echo "  checkit [ARCHIVO] [HASH]         # Verificación Rápida" ;;
    usage_2) echo "  checkit [ARCHIVO] [OPCIONES]     # Calcular Hash (Modo Creación)" ;;
    usage_3) echo "  checkit -c [SUMFILE] [OPCIONES]  # Verificar hashes (Modo Check)" ;;

    sect_examples) echo "Ejemplos Avanzados" ;;
    ex_desc_1) echo "  # Crear un manifiesto BLAKE2 firmado para todas las imágenes ISO:" ;;
    ex_cmd_1) echo "  checkit *.iso --algo b2 --format bsd --sign -o RELEASE.asc" ;;
    ex_desc_2) echo "  # Generar reporte JSON para múltiples archivos:" ;;
    ex_cmd_2) echo "  checkit kernel-* --format json -o listado.json" ;;
    ex_desc_3) echo "  # Verificar integridad y autenticidad (GPG) estricta:" ;;
    ex_cmd_3) echo "  checkit -c RELEASE.asc --verify-sign" ;;

    sect_general) echo "Opciones Generales" ;;
    opt_algo) echo "  -a, --algo <alg>     Especificar algoritmo (md5, sha256, blake2b, etc). Defecto: sha256" ;;
    opt_verify) echo "  -v, --verify-sign    Verificar firma GPG si existe (fuerza modo estricto)" ;;
    opt_copy) echo "  -y, --copy           Copiar salida al portapapeles" ;;
    opt_help) echo "  -h, --help           Mostrar esta ayuda" ;;
    opt_vers) echo "      --version        Mostrar versión" ;;

    sect_create) echo "Opciones Modo Creación" ;;
    opt_all) echo "      --all            Generar hashes con todos los algoritmos seguros" ;;
    opt_sign) echo "  -s, --sign           Firmar la salida con GPG (defecto: clearsign)" ;;
    opt_detach) echo "      --detach-sign    Crear firma separada (requiere escribir a archivo)" ;;
    opt_file) echo "  -f, --file <nombre>  Guardar checksums en archivo (defecto 'CHECKSUMS' si usa --detach-sign)" ;;
    opt_armor) echo "      --armor          Crear salida con armadura ASCII (.asc)" ;;
    opt_out) echo "  -o, --output <arch>  Escribir resultado en archivo (ignora stdout)" ;;
    opt_fmt) echo "      --format <fmt>   Formato de salida: text (gnu), bsd, json, xml" ;;
    opt_tag) echo "      --tag            Forzar salida estilo BSD (alias de --output bsd)" ;;
    opt_zero) echo "  -z, --zero           Terminar cada línea con NUL, no nueva línea" ;;

    sect_check) echo "Opciones Modo Check" ;;
    opt_ignore) echo "      --ignore-missing No fallar ni reportar estado de archivos faltantes" ;;
    opt_quiet) echo "      --quiet          No imprimir OK para cada archivo verificado" ;;
    opt_status) echo "      --status         Sin salida, el código de estado muestra el éxito" ;;
    opt_strict) echo "      --strict         Salir con error si hay líneas mal formateadas" ;;
    opt_warn) echo "  -w, --warn           Advertir sobre líneas de checksum mal formateadas" ;;

    written_by) echo "Escrito por %s." ;;
    license_1) echo "Licencia %s: GNU GPL versión 3 o posterior." ;;
    license_2) echo "Esto es software libre: usted es libre de cambiarlo y redistribuirlo." ;;
    license_3) echo "NO HAY GARANTÍA, en la medida permitida por la ley." ;;
    *) echo "$key" ;;
    esac
  else
    # Default: English
    case "$key" in
    # --- Status Labels ---
    lbl_ok) echo "OK" ;;
    lbl_fail) echo "FAILED" ;;
    lbl_miss) echo "MISSING" ;;
    lbl_skip) echo "SKIPPED" ;;
    lbl_signed) echo "SIGNED" ;;
    lbl_badsig) echo "BAD SIG" ;;

    # --- Report Summary ---
    rpt_prefix) echo " checkit: " ;;
    rpt_bad_fmt_sg) echo "line is improperly formatted" ;;
    rpt_bad_fmt_pl) echo "lines are improperly formatted" ;;
    rpt_skip_sg) echo "file was skipped due to context mismatch" ;;
    rpt_skip_pl) echo "files were skipped due to context mismatch" ;;
    rpt_miss_sg) echo "listed file could not be read" ;;
    rpt_miss_pl) echo "listed files could not be read" ;;
    rpt_fail_sg) echo "computed checksum did NOT match" ;;
    rpt_fail_pl) echo "computed checksums did NOT match" ;;
    rpt_badsig_sg) echo "signature failed verification" ;;
    rpt_badsig_pl) echo "signatures failed verification" ;;
    rpt_verify) echo "Verified" ;;
    rpt_files) echo "files" ;;
    rpt_signed) echo "%s signed" ;;

    # --- Errors & Messages ---
    err_algo_id) echo "Could not identify hash algorithm (length: %s)." ;;
    msg_sig_good) echo "Signature Verified: Good signature found." ;;
    err_sig_bad_strict) echo "BAD signature detected. Aborting strict mode." ;;
    warn_sig_bad) echo "BAD signature detected. Integrity of list is compromised." ;;
    err_sig_missing_strict) echo "Public key missing or GPG error. Cannot verify strict." ;;
    warn_sig_missing) echo "Signed file detected, but Public key missing. Proceeding with hash check." ;;
    err_sig_not_found) echo "--verify-sign requested but no signature found in %s" ;;
    err_calc_fail) echo "Error: Failed to calculate %s for %s" ;;
    msg_saved) echo "    Output saved to: %s" ;;
    msg_sig_created) echo "    Signature created:  %s" ;;
    err_sig_detach_fail) echo "GPG detached signing failed." ;;
    err_sig_fail) echo "GPG signing failed." ;;
    msg_copy_ok) echo "Copied hashes to clipboard." ;;
    warn_arg_missing) echo "Missing arguments." ;;
    err_arg_fmt_invalid) echo "Invalid output format '%s'. Use: text, gnu, bsd, json." ;;
    err_arg_opt_unknown) echo "Unknown option %s" ;;
    err_check_no_file) echo "Missing sumfile argument for check mode." ;;
    err_ambiguous_mode) echo "Ambiguous arguments. Use -c for check mode." ;;

    # --- Standard Help ---
    desc) echo "Advanced file integrity and hash verification tool." ;;
    usage_title) echo "Usage" ;;
    usage_1) echo "  checkit [FILE] [HASH]             # Quick Verify" ;;
    usage_2) echo "  checkit [FILE] [OPTIONS]          # Calculate Hash (Create Mode)" ;;
    usage_3) echo "  checkit -c [SUMFILE] [OPTIONS]    # Check multiple hashes (Check Mode)" ;;

    sect_examples) echo "Advanced Examples" ;;
    ex_desc_1) echo "  # Create a signed BLAKE2 manifest for all ISO images:" ;;
    ex_cmd_1) echo "  checkit *.iso --algo b2 --format bsd --sign -o RELEASE.asc" ;;
    ex_desc_2) echo "  # Generate JSON report for multiple kernel files:" ;;
    ex_cmd_2) echo "  checkit kernel-* --format json -o checksums.json" ;;
    ex_desc_3) echo "  # Verify integrity and GPG authenticity strictly:" ;;
    ex_cmd_3) echo "  checkit -c RELEASE.asc --verify-sign" ;;

    sect_general) echo "General Options" ;;
    opt_algo) echo "  -a, --algo <alg>     Specify algorithm (md5, sha256, blake2b, etc). Default: sha256" ;;
    opt_verify) echo "  -v, --verify-sign    Verify GPG signature if present (enforces strict mode)" ;;
    opt_copy) echo "  -y, --copy           Copy output to clipboard" ;;
    opt_help) echo "  -h, --help           Show this help" ;;
    opt_vers) echo "      --version        Show version" ;;

    sect_create) echo "Create Mode Options" ;;
    opt_all) echo "      --all            Generate hashes using all safe algorithms" ;;
    opt_sign) echo "  -s, --sign           Sign the output using GPG (default: clearsign)" ;;
    opt_detach) echo "      --detach-sign    Create a detached signature (requires writing to file)" ;;
    opt_file) echo "  -f, --file <name>    Save checksums to file (default 'CHECKSUMS' if using --detach-sign)" ;;
    opt_armor) echo "      --armor          Create ASCII armored output (.asc)" ;;
    opt_out) echo "  -o, --output <file>  Write output to file (suppress stdout)" ;;
    opt_fmt) echo "      --format <fmt>   Select output format: text (gnu), bsd, json, xml" ;;
    opt_tag) echo "      --tag            Force BSD style output (alias for --output bsd)" ;;
    opt_zero) echo "  -z, --zero           End each output line with NUL, not newline" ;;

    sect_check) echo "Check Mode Options" ;;
    opt_ignore) echo "      --ignore-missing Don't fail or report status for missing files" ;;
    opt_quiet) echo "      --quiet          Don't print OK for each successfully verified file" ;;
    opt_status) echo "      --status         Don't output anything, status code shows success" ;;
    opt_strict) echo "      --strict         Exit non-zero for improperly formatted checksum lines" ;;
    opt_warn) echo "  -w, --warn           Warn about improperly formatted checksum lines" ;;

    written_by) echo "Written by %s." ;;
    license_1) echo "License %s: GNU GPL version 3 or later." ;;
    license_2) echo "This is free software: you are free to change and redistribute it." ;;
    license_3) echo "There is NO WARRANTY, to the extent permitted by law." ;;
    *) echo "$key" ;;
    esac
  fi
}

# ----------------------------------------------------------------------
# 3. Public Functions
# ----------------------------------------------------------------------

# Public: Formats translated messages safely suppressing SC2059.
# Wraps printf to handle dynamic format strings from the trusted dictionary.
#
# $1      - key  - The message key to retrieve.
# $...    - args - Variable arguments to format into the string.
#
# Returns nothing (prints to stderr).
ui::fmt_msg() {
  local key="$1"
  shift
  local format_str
  format_str=$(ui::get_msg "$key")

  # shellcheck disable=SC2059
  printf -- "$format_str" "$@"
}

# Public: Renders the status of a processed file to stderr.
# Interprets the internal status key to select the correct color and icon.
#
# $1 - status_key   - The internal constant string (e.g., $ST_OK, $ST_FAIL).
# $2 - file         - The filename string to display.
# $3 - info         - (Optional) Algorithm used or technical reason string.
# $4 - extra_status - (Optional) Secondary status key (e.g., $ST_SIGNED).
#
# Returns nothing.
ui::log_file_status() {
  local status_key="$1"
  local file="$2"
  local info="${3:-}"
  local extra_status="${4:-}"

  # Local variables for display
  local symbol color label extra_text=""

  case "$status_key" in
  "$ST_OK")
    if [[ "${__CLI_STATUS:-false}" == "true" ]]; then return; fi
    if [[ "${__CLI_QUIET:-false}" == "true" ]]; then return; fi
    symbol="$SYMBOL_CHECK"
    color="$C_GREEN"
    label=$(ui::get_msg "lbl_ok")

    # Handle GPG sub-status
    if [[ "$extra_status" == "$ST_SIGNED" ]]; then
      local sig_lbl
      sig_lbl=$(ui::get_msg "lbl_signed")
      extra_text=" ${C_GREENH}${SYMBOL_SIGNED:-[$sig_lbl]}${C_R}"
    elif [[ "$extra_status" == "$ST_BAD_SIG" ]]; then
      local sig_lbl
      sig_lbl=$(ui::get_msg "lbl_badsig")
      extra_text=" ${C_REDH}${SYMBOL_BAD:-[$sig_lbl]}${C_R}"
    fi

    echo -e "${color}${symbol:-[$label]} $file${C_R} ($info)${extra_text}" >&2
    ;;

  "$ST_FAIL")
    if [[ "${__CLI_STATUS:-false}" == "true" ]]; then return; fi
    symbol="$SYMBOL_FAILED"
    color="$C_RED"
    label=$(ui::get_msg "lbl_fail")
    # Info here usually contains the algo or reason
    echo -e "${color}${symbol:-[$label]} $file${C_R} ($info)" >&2
    ;;

  "$ST_MISSING")
    if [[ "${__CLI_IGNORE_MISSING:-false}" == "true" ]]; then return; fi
    symbol="$SYMBOL_MISSING"
    color="$C_MSG1"
    label=$(ui::get_msg "lbl_miss")
    echo -e "${color}${symbol:-[$label]} $file${C_R}" >&2
    ;;

  "$ST_SKIP")
    if [[ "${__CLI_STATUS:-false}" == "true" ]]; then return; fi
    symbol="$SYMBOL_SKIPPED"
    color="$C_LORANGE"
    label=$(ui::get_msg "lbl_skip")
    # Info contains the reason (e.g. "Not a SHA hash")
    echo -e "${color}${symbol:-[$label]} $file${C_R}${C_MSG2} ($info)${C_R}" >&2
    ;;

  *)
    # Fallback for unknown states
    echo -e "${C_MSG1}[UNKNOWN] $file${C_R}" >&2
    ;;
  esac
}

# Public: Calculates and prints the final summary block using translated strings.
# Aggregates counters for OK, FAILED, MISSING, etc.
#
# $1 - cnt_ok        - Count of verified files.
# $2 - cnt_failed    - Count of checksum mismatches.
# $3 - cnt_missing   - Count of missing files.
# $4 - cnt_skipped   - Count of skipped files.
# $5 - cnt_bad_sig   - Count of bad GPG signatures.
# $6 - cnt_signed    - Count of good GPG signatures.
# $7 - cnt_bad_lines - Count of malformed lines.
#
# Returns nothing.
ui::log_report_summary() {
  local cnt_ok="$1"
  local cnt_failed="$2"
  local cnt_missing="$3"
  local cnt_skipped="$4"
  local cnt_bad_sig="$5"
  local cnt_signed="$6"
  local cnt_bad_lines="$7"

  local prefix
  prefix=$(ui::get_msg "rpt_prefix")

  # Internal: Helper to print summary lines if count > 0.
  _print_sum() {
    local cnt="$1"
    local clr="$2"
    local sym="$3"
    local k_sg="$4"
    local k_pl="$5"

    if [[ "$cnt" -gt 0 ]]; then
      local msg
      if [[ "$cnt" -eq 1 ]]; then
        msg=$(ui::get_msg "$k_sg")
      else
        msg=$(ui::get_msg "$k_pl")
      fi
      echo -e "${prefix}${clr}${sym}${C_R} $cnt ${C_MSG2}$msg${C_R}" >&2
    fi
  }

  # 1. BAD LINES
  if [[ "$__CLI_WARN" == "true" || "$__CLI_STRICT" == "true" ]]; then
    _print_sum "$cnt_bad_lines" "$C_ORANGE" "$SYMBOL_REPORT" "rpt_bad_fmt_sg" "rpt_bad_fmt_pl"
  fi

  # 2. SKIPPED
  _print_sum "$cnt_skipped" "$C_ORANGE" "$SYMBOL_REPORT" "rpt_skip_sg" "rpt_skip_pl"

  # 3. MISSING
  if [[ "$__CLI_IGNORE_MISSING" != "true" ]]; then
    _print_sum "$cnt_missing" "$C_ORANGE" "$SYMBOL_REPORT" "rpt_miss_sg" "rpt_miss_pl"
  fi

  # 4. FAILED
  _print_sum "$cnt_failed" "$C_ORANGE" "$SYMBOL_REPORT" "rpt_fail_sg" "rpt_fail_pl"

  # 5. BAD SIGNATURES
  _print_sum "$cnt_bad_sig" "$C_ORANGE" "$SYMBOL_REPORT" "rpt_badsig_sg" "rpt_badsig_pl"

  # 6. VERIFIED (SUCCESS)
  if [[ "$__CLI_QUIET" != "true" && "$cnt_ok" -gt 0 ]]; then
    local v_txt
    local f_txt
    v_txt=$(ui::get_msg "rpt_verify")
    f_txt=$(ui::get_msg "rpt_files")

    local summary="${prefix}${C_ORANGE}${SYMBOL_REPORT}${C_R} $cnt_ok ${C_MSG2}${v_txt}${C_R} ${C_MSG2}${f_txt}${C_R}"

    if [[ "$cnt_signed" -gt 0 ]]; then
      local s_txt
      s_txt="$(ui::fmt_msg "$(ui::get_msg "rpt_signed")" "$cnt_signed")"
      summary="$summary (${C_GREENH}${s_txt}${C_R})"
    fi
    echo -e "$summary." >&2
  fi
}

# Public: Logs an info message to stderr.
#
# $1 - message - The string to log.
ui::log_info() {
  if [[ "${__CLI_QUIET:-false}" == "false" ]]; then
    echo -e "${C_CYAN}${SYMBOL_INFO}$1${C_R}" >&2
  fi
}

# Public: Logs a warning message to stderr.
#
# $1 - message - The string to log.
ui::log_warning() {
  echo -e "${C_ORANGE}${SYMBOL_WARNING} $1${C_R}" >&2
}

# Public: Logs a critical error message to stderr.
#
# $1 - message - The string to log.
ui::log_critical() {
  echo -e "${C_RED}${SYMBOL_CRITICAL} $1${C_R}" >&2
}

# Public: Logs a standard error message to stderr.
#
# $1 - message - The string to log.
ui::log_error() {
  echo -e "${C_RED}${SYMBOL_ERROR} $1${C_R}" >&2
}

# Public: Logs a clipboard action message.
#
# $1 - message - The string to log.
ui::log_clipboard() {
  echo -e "${C_CYANG} ${SYMBOL_CLIPB}$1${C_R}" >&2
}

# Public: Displays the version information and license.
# Uses localized strings.
ui::show_version() {
  echo -e "${C_BOLD}${APP_NAME}${C_R} ${C_CYAN}v${CHECKIT_VERSION}${C_R}"
  printf "Copyright (C) %s %s.\n" "$APP_YEAR" "$APP_AUTHOR"
  ui::fmt_msg "$(ui::get_msg "license_1")\n" "$APP_LICENSE"
  ui::get_msg "license_2"
  ui::get_msg "license_3"
  echo ""
  ui::fmt_msg "$(ui::get_msg "written_by")\n" "$APP_AUTHOR"
}

# Public: Displays the help menu with all available options.
# Uses localized strings for section headers and descriptions.
ui::show_help() {
  echo -e "${C_BOLD}${APP_NAME}${C_R} v${CHECKIT_VERSION}"
  ui::get_msg "desc"
  echo ""

  echo -e "${C_YELLOW}$(ui::get_msg "usage_title"):${C_R}"
  ui::get_msg "usage_1"
  ui::get_msg "usage_2"
  ui::get_msg "usage_3"
  echo ""

  echo -e "${C_YELLOW}$(ui::get_msg "sect_general"):${C_R}"
  ui::get_msg "opt_algo"
  ui::get_msg "opt_verify"
  ui::get_msg "opt_copy"
  ui::get_msg "opt_help"
  ui::get_msg "opt_vers"
  echo ""

  echo -e "${C_YELLOW}$(ui::get_msg "sect_create"):${C_R}"
  ui::get_msg "opt_all"
  ui::get_msg "opt_sign"
  ui::get_msg "opt_detach"
  ui::get_msg "opt_file"
  ui::get_msg "opt_armor"
  ui::get_msg "opt_out"
  ui::get_msg "opt_fmt"
  ui::get_msg "opt_tag"
  ui::get_msg "opt_zero"
  echo ""

  echo -e "${C_YELLOW}$(ui::get_msg "sect_check"):${C_R}"
  ui::get_msg "opt_ignore"
  ui::get_msg "opt_quiet"
  ui::get_msg "opt_status"
  ui::get_msg "opt_strict"
  ui::get_msg "opt_warn"
  echo ""
  # --- Examples ---
  echo -e "${C_YELLOW}$(ui::get_msg "sect_examples"):${C_R}"
  echo -e "$(ui::get_msg "ex_desc_1")"
  echo -e "${C_ORANGE}$(ui::get_msg "ex_cmd_1")${C_R}"
  echo ""
  echo -e "$(ui::get_msg "ex_desc_2")"
  echo -e "${C_ORANGE}$(ui::get_msg "ex_cmd_2")${C_R}"
  echo ""
  echo -e "$(ui::get_msg "ex_desc_3")"
  echo -e "${C_ORANGE}$(ui::get_msg "ex_cmd_3")${C_R}"
  echo ""
  echo -e "${C_MAGENTA}Report bugs: ${C_R}${C_BLUE}${APP_WEBSITE}${C_R}"
}
