#!/usr/bin/env bash

# UI Adapter: Handles User Output, Colors, Icons, and Help Menu
# Responsibility: Present information to the user in the correct language.

# 1. Language Detection
# ---------------------
# Detect whether system locale is Spanish
UI_LANG="en"
if [[ "${LANG:-}" == *"es_"* || "${LC_ALL:-}" == *"es_"* ]]; then
  UI_LANG="es"
fi

# 2. Message Dictionary (Portable Function)
# -----------------------------------------
# Use a case statement instead of associative arrays for maximum POSIX compatibility
ui::get_msg() {
  local key="$1"

  if [[ "$UI_LANG" == "es" ]]; then
    case "$key" in
    desc) echo "Herramienta avanzada de integridad y verificación de hashes." ;;
    usage_title) echo "Uso" ;;
    usage_1) echo "  checkit [ARCHIVO] [HASH]         # Verificación Rápida" ;;
    usage_2) echo "  checkit [ARCHIVO] [OPCIONES]     # Calcular Hash (Modo Creación)" ;;
    usage_3) echo "  checkit -c [SUMFILE] [OPCIONES]  # Verificar hashes (Modo Check)" ;;

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
    opt_out) echo "  -o, --output <fmt>   Formato de salida: text (gnu), bsd, json, xml" ;;
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
    desc) echo "Advanced file integrity and hash verification tool." ;;
    usage_title) echo "Usage" ;;
    usage_1) echo "  checkit [FILE] [HASH]            # Quick Verify" ;;
    usage_2) echo "  checkit [FILE] [OPTIONS]         # Calculate Hash (Create Mode)" ;;
    usage_3) echo "  checkit -c [SUMFILE] [OPTIONS]   # Check multiple hashes (Check Mode)" ;;

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
    opt_out) echo "  -o, --output <fmt>   Output format: text (gnu), bsd, json, xml" ;;
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

# 3. Public Functions
# -------------------

# ui::log_info <message>
ui::log_info() {
  if [[ "${__CLI_QUIET:-false}" == "false" ]]; then
    echo -e "${C_CYAN}${SYMBOL_INFO}$1${C_R}" >&2
  fi
}

# ui::log_success <message>
ui::log_success() {
  # Print green check only when not in quiet or status mode
  if [[ "${__CLI_QUIET:-false}" == "false" && "${__CLI_STATUS:-false}" == "false" ]]; then
    echo -e "${C_GREEN}${SYMBOL_CHECK}$1${C_R}$2"
  fi
}

# ui::log_skipped <message>
ui::log_skipped() {
  echo -e "${C_LORANGE}${SYMBOL_SKIPPED}$1${C_R}"
}

# ui::log_failed <message>
ui::log_failed() {
  echo -e "${C_RED}${SYMBOL_FAILED}$1${C_R}"
}

# ui::log_warning <message>
ui::log_warning() {
  echo -e "${C_ORANGE}${SYMBOL_WARNING}$1${C_R}" >&2
}

# ui::log_missing <message>
ui::log_missing() {
  if [[ "${__CLI_IGNORE_MISSING:-false}" == "false" ]]; then
    echo -e "${C_MSG1}${SYMBOL_MISSING}$1${C_R}" >&2
  fi
}

ui::log_critical() {
  echo -e "${C_RED}${SYMBOL_CRITICAL}$1${C_R}" >&2
}

# ui::log_error <message>
ui::log_error() {
  echo -e "${C_RED}${SYMBOL_ERROR}$1${C_R}" >&2
}

# ui::log_report <message>
ui::log_report() {
  echo -e "checkit:${C_ORANGE}${SYMBOL_REPORT}${C_R}$1${C_MSG2}$2${C_R}" >&2
}

# ui::log_clipboard <message>
ui::log_clipboard() {
  echo -e "${C_CYANG}   ${SYMBOL_CLIPB}$1${C_R}" >&2
}

# ui::show_version
# shellcheck disable=SC2059
ui::show_version() {
  # Header
  echo -e "${C_BOLD}${APP_NAME}${C_R} ${C_CYAN}v${CHECKIT_VERSION}${C_R}"
  printf "Copyright (C) %s %s.\n" "$APP_YEAR" "$APP_AUTHOR"

  # License Block
  printf "$(ui::get_msg "license_1")\n" "$APP_LICENSE"
  ui::get_msg "license_2"
  ui::get_msg "license_3"
  echo ""

  # Author Block
  printf "$(ui::get_msg "written_by")\n" "$APP_AUTHOR"
}

# ui::show_help
ui::show_help() {
  # Banner
  echo -e "${C_BOLD}${APP_NAME}${C_R} v${CHECKIT_VERSION}"
  ui::get_msg "desc"
  echo ""

  # Usage Section
  echo -e "${C_YELLOW}$(ui::get_msg "usage_title"):${C_R}"
  ui::get_msg "usage_1"
  ui::get_msg "usage_2"
  ui::get_msg "usage_3"
  echo ""

  # General Options
  echo -e "${C_YELLOW}$(ui::get_msg "sect_general"):${C_R}"
  ui::get_msg "opt_algo"
  ui::get_msg "opt_verify"
  ui::get_msg "opt_copy"
  ui::get_msg "opt_help"
  ui::get_msg "opt_vers"
  echo ""

  # Create Options
  echo -e "${C_YELLOW}$(ui::get_msg "sect_create"):${C_R}"
  ui::get_msg "opt_all"
  ui::get_msg "opt_sign"
  ui::get_msg "opt_detach"
  ui::get_msg "opt_file"
  ui::get_msg "opt_armor"
  ui::get_msg "opt_out"
  ui::get_msg "opt_tag"
  ui::get_msg "opt_zero"
  echo ""

  # Check Options
  echo -e "${C_YELLOW}$(ui::get_msg "sect_check"):${C_R}"
  ui::get_msg "opt_ignore"
  ui::get_msg "opt_quiet"
  ui::get_msg "opt_status"
  ui::get_msg "opt_strict"
  ui::get_msg "opt_warn"
  echo ""

  # Footer Signature
  echo -e "${C_MAGENTA}Report bugs: ${C_R}${C_BLUE}${APP_WEBSITE}${C_R}"
}
