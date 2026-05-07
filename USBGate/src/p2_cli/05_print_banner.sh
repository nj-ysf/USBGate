#!/usr/bin/env bash
# ============================================================
#  USBGate - P2 - Function 05 : print_banner()
#  Affiche le titre stylise + infos d'execution au lancement.
#  Utilise les variables d'environnement $USER et $HOME (§3.2.2).
# ============================================================

# ---------- COULEURS ANSI ----------
CYAN="\033[0;36m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RESET="\033[0m"

# ---------- VERSION & METADATA ----------
USBGATE_VERSION="1.0"
USBGATE_DATE_BUILD="2026-05"

# ---------- VARIABLES (definies par d'autres fonctions) ----------
USB_DEVICE="${USB_DEVICE:-/dev/sdX}"     # default placeholder for standalone test
LOG_FILE="${LOG_FILE:-/var/log/usbgate/history.log}"

# ============================================================
#  print_banner() - banniere ASCII + infos systeme
# ============================================================
print_banner() {
    # Bloc ASCII art en cyan (here-doc avec 'EOF' pour preserver les \)
    echo -e "${CYAN}"
    cat <<'EOF'
   _   _ ____  ____   ____       _
  | | | / ___|| __ ) / ___| __ _| |_ ___
  | | | \___ \|  _ \| |  _ / _` | __/ _ \
  | |_| |___) | |_) | |_| | (_| | ||  __/
   \___/|____/|____/ \____|\__,_|\__\___|
EOF
    echo -e "${RESET}"

    # Bloc infos contextuelles (variables d'environnement obligatoires)
    echo -e "  ${GREEN}USBGate v${USBGATE_VERSION}${RESET} - Bash Shell Project 2026"
    echo "  ---------------------------------------------------"
    printf "  %-12s : %s\n" "Date"     "$(date '+%Y-%m-%d %H:%M:%S')"
    printf "  %-12s : %s\n" "User"     "${USER}"
    printf "  %-12s : %s\n" "Home"     "${HOME}"
    printf "  %-12s : %s\n" "Hostname" "$(hostname)"
    printf "  %-12s : %s\n" "Device"   "${USB_DEVICE}"
    printf "  %-12s : %s\n" "Log file" "${LOG_FILE}"
    echo "  ---------------------------------------------------"
    echo ""
}

# ============================================================
#  TEST STANDALONE
# ============================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Simuler des valeurs comme si parse_args avait deja tourne
    USB_DEVICE="/dev/sdb1"
    LOG_FILE="/var/log/usbgate/history.log"
    print_banner
fi