#!/usr/bin/env bash
# ============================================================
#  USBGate - Point d'entree principal
#  Usage : ./usbgate1.sh [options] <device|auto>
# ============================================================

# Chemin absolu — compatible WSL, sudo, et liens symboliques
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/src"

# ============================================================
#  VARIABLES GLOBALES PARTAGEES
# ============================================================
USB_DEVICE=""
MOUNT_POINT="/mnt/usbgate"
LOG_DIR="/var/log/usbgate"
LOG_FILE="${LOG_DIR}/history.log"
CUSTOM_LOG_DIR=""
SAFE_DEST="${HOME}/Downloads/SecureImport"
TMP_RESULTS="/tmp/usbgate_results.tmp"

OPT_FORK=false
OPT_THREAD=false
OPT_SUBSHELL=false
OPT_RESTORE=false

COUNT_SAFE=0
COUNT_MEDIUM=0
COUNT_HIGH=0
VIRUS_FOUND=false

E_OK=0
E_BAD_OPTION=100
E_MISSING_PARAM=101
E_NOT_ROOT=102
E_MOUNT_FAIL=103
E_NO_DEVICE=104
E_LOG_FAIL=105
E_RESTORE_DENIED=106

USBGATE_VERSION="1.0"

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

# ============================================================
#  VERIFICATION : affiche les fichiers manquants
# ============================================================
MODULES=(
    "${SRC_DIR}/p3_core/core.functions.sh"
    "${SRC_DIR}/p1_detection/detection.functions.sh"
    "${SRC_DIR}/p4_ui_import/ui.functions.sh"
    "${SRC_DIR}/p2_cli/01_show_help.sh"
    "${SRC_DIR}/p2_cli/02_parse_args.sh"
    "${SRC_DIR}/p2_cli/03_require_root.sh"
    "${SRC_DIR}/p2_cli/04_auto_detect.sh"
    "${SRC_DIR}/p2_cli/05_print_banner.sh"
    "${SRC_DIR}/p2_cli/06_main.sh"
)

all_ok=true
for m in "${MODULES[@]}"; do
    if [[ ! -f "${m}" ]]; then
        echo "[FATAL] Fichier manquant : ${m}" >&2
        all_ok=false
    else
        :
    fi
done

[[ "${all_ok}" == false ]] && exit 1

# ============================================================
#  CHARGEMENT DES MODULES
# ============================================================
source "${SRC_DIR}/p3_core/core.functions.sh"
source "${SRC_DIR}/p1_detection/detection.functions.sh"
source "${SRC_DIR}/p4_ui_import/ui.functions.sh"

source "${SRC_DIR}/p2_cli/01_show_help.sh"
source "${SRC_DIR}/p2_cli/02_parse_args.sh"
source "${SRC_DIR}/p2_cli/03_require_root.sh"
source "${SRC_DIR}/p2_cli/04_auto_detect.sh"
source "${SRC_DIR}/p2_cli/05_print_banner.sh"
source "${SRC_DIR}/p2_cli/06_main.sh"

# ============================================================
#  HELPER
# ============================================================
get_scan_mode() {
    if   [[ "${OPT_FORK}"     == true ]]; then echo "fork"
    elif [[ "${OPT_THREAD}"   == true ]]; then echo "thread"
    elif [[ "${OPT_SUBSHELL}" == true ]]; then echo "subshell"
    else                                        echo "normal"
    fi
}

# ============================================================
#  LANCEMENT
# ============================================================
main "$@"
