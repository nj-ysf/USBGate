#!/usr/bin/env bash
# ============================================================
#  USBGate — Secure USB Key Scanner
#  ENSET Mohammedia — Mini Projet Shell 2026
#  Usage: sudo usbgate.sh [options] <device|auto>
#
#  P1 — Detection   : classify_file, scan_with_clamav
#  P2 — CLI         : show_help, parse_args, require_root,
#                     auto_detect_device, print_banner, main
#  P3 — Core        : init_log, log_info, log_error,
#                     mount_usb, unmount_usb,
#                     scan_file, scan_all_files
#  P4 — UI/Import   : print_risk, show_summary, interactive_menu,
#                     import_safe_files, generate_report,
#                     restore_defaults
# ============================================================

# ============================================================
#  GLOBAL VARIABLES  (P2 — 06_main.sh)
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

CYAN="\033[0;36m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BOLD="\033[1m"
RESET="\033[0m"

# ============================================================
#  P3 — LOGGING
# ============================================================

init_log() {
    if [[ -n "${CUSTOM_LOG_DIR}" ]]; then
        LOG_DIR="${CUSTOM_LOG_DIR}"
        LOG_FILE="${LOG_DIR}/history.log"
    fi
    mkdir -p "${LOG_DIR}" 2>/dev/null || {
        echo "[ERROR] Impossible de creer le dossier logs" >&2
        exit ${E_LOG_FAIL}
    }
    touch "${LOG_FILE}" 2>/dev/null || {
        echo "[ERROR] Impossible de creer le fichier log" >&2
        exit ${E_LOG_FAIL}
    }
}

log_info() {
    local ts; ts=$(date '+%Y-%m-%d-%H-%M-%S')
    local user; user=$(whoami)
    echo "${ts} : ${user} : INFOS : $*" | tee -a "${LOG_FILE}"
}

log_error() {
    local ts; ts=$(date '+%Y-%m-%d-%H-%M-%S')
    local user; user=$(whoami)
    echo "${ts} : ${user} : ERROR : $*" | tee -a "${LOG_FILE}" >&2
}

# ============================================================
#  P3 — MOUNT / UNMOUNT
# ============================================================

mount_usb() {
    local device="$1"
    mkdir -p "${MOUNT_POINT}"
    if mount -o ro "${device}" "${MOUNT_POINT}" 2>/dev/null; then
        log_info "Montage reussi en lecture seule : ${MOUNT_POINT}"
    else
        log_error "Echec du montage de ${device}"
        exit ${E_MOUNT_FAIL}
    fi
}

unmount_usb() {
    if mountpoint -q "${MOUNT_POINT}" 2>/dev/null; then
        umount "${MOUNT_POINT}"
        rmdir "${MOUNT_POINT}" 2>/dev/null
        log_info "Cle USB demontee proprement"
    else
        log_info "Aucun montage actif detecte"
    fi
}

# ============================================================
#  P3 — SCAN ENGINE
# ============================================================

scan_file() {
    local filepath="$1"
    local filename; filename=$(basename "${filepath}")
    local risk; risk=$(classify_file "${filepath}")
    print_risk "${risk}" "${filename}"
    log_info "Scanne : ${filename} -> ${risk}"
    echo "${risk}" >> "${TMP_RESULTS}"
}

scan_all_files() {
    local dir="$1"
    local mode="${2:-normal}"

    rm -f "${TMP_RESULTS}"
    touch "${TMP_RESULTS}"

    mapfile -t files < <(find "${dir}" -type f 2>/dev/null)
    log_info "Scan mode : ${mode} | Fichiers : ${#files[@]}"

    case "${mode}" in
        normal)
            for f in "${files[@]}"; do scan_file "${f}"; done
            ;;
        fork)
            for f in "${files[@]}"; do ( scan_file "${f}" ) & done
            wait
            ;;
        thread)
            local job_count=0
            for f in "${files[@]}"; do
                scan_file "${f}" &
                (( job_count++ ))
                if (( job_count >= 4 )); then wait; job_count=0; fi
            done
            wait
            ;;
        subshell)
            ( for f in "${files[@]}"; do scan_file "${f}"; done )
            ;;
        *)
            log_error "Mode de scan inconnu : ${mode}"
            return 1
            ;;
    esac

    COUNT_SAFE=$(  grep -c "^SAFE$"   "${TMP_RESULTS}" 2>/dev/null || echo 0)
    COUNT_MEDIUM=$(grep -c "^MEDIUM$" "${TMP_RESULTS}" 2>/dev/null || echo 0)
    COUNT_HIGH=$(  grep -c "^HIGH$"   "${TMP_RESULTS}" 2>/dev/null || echo 0)
    log_info "Resultats -> SAFE=${COUNT_SAFE} MEDIUM=${COUNT_MEDIUM} HIGH=${COUNT_HIGH}"
}

# ============================================================
#  P1 — DETECTION
# ============================================================

classify_file() {
    local filepath="$1"
    local filename; filename=$(basename "$filepath")
    local ext="${filename##*.}"

    # Rule 1 — Double extension
    if echo "$filename" | grep -qE '\.[a-zA-Z]+\.(exe|sh|bat|elf|vbs)$'; then
        echo "HIGH"; return
    fi

    # Rule 2 — Dangerous extension
    if echo "$ext" | grep -qE '^(exe|sh|elf|bat|vbs|jar|ps1|cmd)$'; then
        echo "HIGH"; return
    fi

    # Rule 3 — Executable MIME type
    local mime; mime=$(file --mime-type -b "$filepath")
    if echo "$mime" | grep -qE 'application/(x-executable|x-sh|x-dosexec)'; then
        echo "HIGH"; return
    fi

    # Rule 4 — Executable permission
    if [[ -x "$filepath" ]]; then
        echo "HIGH"; return
    fi

    # Rule 5 — 777 permissions
    local perms; perms=$(stat -c "%a" "$filepath")
    if [[ "$perms" == "777" ]]; then
        echo "HIGH"; return
    fi

    # Rule 6 — Hidden file
    if [[ "$filename" == .* ]]; then
        echo "MEDIUM"; return
    fi

    # Rule 7 — Archive
    if echo "$ext" | grep -qE '^(zip|rar|tar|gz|7z|iso)$'; then
        echo "MEDIUM"; return
    fi

    echo "SAFE"
}

scan_with_clamav() {
    local usb_path="$1"

    if ! command -v clamscan >/dev/null 2>&1; then
        log_info "ClamAV n'est pas installe. Scan antivirus ignore."
        VIRUS_FOUND=false
        return
    fi

    clamscan -r --bell "$usb_path"
    local result=$?

    if [[ "$result" -eq 1 ]]; then
        VIRUS_FOUND=true
        log_error "Virus detecte ! Import bloque."
        echo "ALERTE ROUGE : un virus a ete trouve."
    elif [[ "$result" -eq 0 ]]; then
        VIRUS_FOUND=false
        log_info "Aucun virus detecte."
    else
        VIRUS_FOUND=false
        log_error "Erreur pendant le scan ClamAV."
    fi
}

# ============================================================
#  P4 — INTERFACE & IMPORT
# ============================================================

print_risk() {
    local level="$1" name="$2"
    case "${level}" in
        SAFE)   echo -e " [${GREEN}SAFE   ${RESET}] ${name}" ;;
        MEDIUM) echo -e " [${YELLOW}MEDIUM ${RESET}] ${name}" ;;
        HIGH)   echo -e " [${RED}HIGH   ${RESET}] ${name}" ;;
    esac
}

show_summary() {
    local inner_width=42
    echo ""
    echo " ╔══════════════════════════════════════════╗"
    echo " ║             SCAN SUMMARY                 ║"
    echo " ╠══════════════════════════════════════════╣"
    local labels=("Safe files    :" "Suspect files :" "Dangerous     :")
    local colors=("${GREEN}" "${YELLOW}" "${RED}")
    local counts=("${COUNT_SAFE}" "${COUNT_MEDIUM}" "${COUNT_HIGH}")
    for i in 0 1 2; do
        local inner=" ${labels[$i]} ${counts[$i]}"
        local padding=$(( inner_width - ${#inner} ))
        [[ $padding -lt 0 ]] && padding=0
        echo -e " ║${colors[$i]}${inner}$(printf '%*s' $padding)${RESET}║"
    done
    echo " ╚══════════════════════════════════════════╝"
    log_info "Resume : SAFE=${COUNT_SAFE} MEDIUM=${COUNT_MEDIUM} HIGH=${COUNT_HIGH}"
}

interactive_menu() {
    while true; do
        echo ""
        echo " ╔══════════════════════════════════════════╗"
        echo " ║         MENU INTERACTIF                  ║"
        echo " ╠══════════════════════════════════════════╣"
        echo " ║  1) Copier uniquement les fichiers SAFE  ║"
        echo " ║  2) Generer un rapport detaille          ║"
        echo " ║  3) Quitter et demonter la cle           ║"
        echo " ╚══════════════════════════════════════════╝"
        read -rp " Choix [1-3]: " choice
        case "${choice}" in
            1) import_safe_files ;;
            2) generate_report ;;
            3) log_info "Sortie utilisateur."; echo -e "\n ${GREEN}Au revoir.${RESET}"; return ;;
            *) echo -e " ${YELLOW}Choix invalide.${RESET}" ;;
        esac
    done
}

import_safe_files() {
    mkdir -p "${SAFE_DEST}" 2>/dev/null || {
        log_error "Impossible de creer le dossier ${SAFE_DEST}"
        return 1
    }
    local copied=0 total=0
    while IFS= read -r -d "" filepath; do
        (( total++ ))
        local risk; risk=$(classify_file "${filepath}")
        if [[ "${risk}" == "SAFE" ]]; then
            cp "${filepath}" "${SAFE_DEST}/" 2>/dev/null && (( copied++ ))
            log_info "Copie : $(basename "${filepath}")"
        fi
    done < <(find "${MOUNT_POINT}" -type f -print0 2>/dev/null)
    echo -e "\n ${GREEN}${copied} fichier(s) SAFE copie(s) sur ${total}.${RESET}"
    echo -e " ${CYAN}Destination : ${SAFE_DEST}${RESET}"
    log_info "Import termine : ${copied}/${total} fichiers SAFE copies."
}

generate_report() {
    local report="/tmp/usbgate_report_$(date '+%Y%m%d_%H%M%S').txt"
    {
        echo "=============================="
        echo " USBGate Security Report"
        echo "=============================="
        echo " Date      : $(date '+%Y-%m-%d %H:%M:%S')"
        echo " Device    : ${USB_DEVICE:-inconnu}"
        echo " Operateur : $(whoami)"
        echo " Hostname  : $(hostname)"
        echo ""
        echo "--- RESUME ---"
        echo " SAFE   : ${COUNT_SAFE:-0}"
        echo " MEDIUM : ${COUNT_MEDIUM:-0}"
        echo " HIGH   : ${COUNT_HIGH:-0}"
        echo ""
        echo "--- LISTE DES FICHIERS ---"
        find "${MOUNT_POINT}" -type f 2>/dev/null | sort | while read -r f; do
            local risk; risk=$(classify_file "$f")
            echo " [${risk}] ${f#${MOUNT_POINT}/}"
        done
        echo ""
        echo "--- FIN DU RAPPORT ---"
    } | tee "${report}"
    gzip "${report}" 2>/dev/null && {
        log_info "Rapport genere : ${report}.gz"
        echo -e "\n ${CYAN}Rapport : ${report}.gz${RESET}"
    } || log_error "Echec compression rapport."
}

restore_defaults() {
    if [[ $(id -u) -ne 0 ]]; then
        log_error "L'option -r necessite les droits root."
        show_help
        exit ${E_RESTORE_DENIED}
    fi
    log_info "Restauration des parametres par defaut..."
    unmount_usb
    > "${LOG_FILE}" 2>/dev/null
    rm -rf "${SAFE_DEST}" 2>/dev/null
    rm -f /tmp/usbgate_* 2>/dev/null
    log_info "Restauration terminee."
    echo -e " ${GREEN}Restauration terminee.${RESET}"
}

# ============================================================
#  P2 — CLI
# ============================================================

show_help() {
    cat <<'EOF'
USAGE
    sudo usbgate.sh [options] <device|auto>

OPTIONS
    -h              Afficher cette aide
    -f              Mode fork    : scan via sous-processus
    -t              Mode thread  : scan via jobs en parallele
    -s              Mode subshell: scan dans un sous-shell
    -l <dir>        Choisir le dossier de stockage des logs
    -r              Restaurer les parametres par defaut [ROOT only]

EXIT CODES
      0   Succes
    100   Option inconnue
    101   Parametre obligatoire manquant
    102   Droits administrateur requis
    103   Echec du montage USB
    104   Peripherique non trouve
    105   Echec initialisation log
    106   Restauration refusee (pas root)

EXEMPLES
    sudo usbgate.sh auto
    sudo usbgate.sh -f /dev/sdb1
    sudo usbgate.sh -t -l /tmp/meslogs /dev/sdc1
    sudo usbgate.sh -r

USBGate v1.0 - Bash Shell Project 2026
EOF
}

parse_args() {
    OPTIND=1
    while getopts ":hftsl:r" opt; do
        case "${opt}" in
            h) show_help; exit ${E_OK} ;;
            f) OPT_FORK=true ;;
            t) OPT_THREAD=true ;;
            s) OPT_SUBSHELL=true ;;
            l) CUSTOM_LOG_DIR="${OPTARG}" ;;
            r) OPT_RESTORE=true ;;
            \?) log_error "Option inconnue : -${OPTARG}"; show_help; exit ${E_BAD_OPTION} ;;
            :)  log_error "Option -${OPTARG} necessite un argument"; show_help; exit ${E_BAD_OPTION} ;;
        esac
    done
    shift $((OPTIND - 1))
    if [[ -z "$1" && "${OPT_RESTORE}" == false ]]; then
        log_error "Parametre obligatoire manquant : <device|auto>"
        show_help
        exit ${E_MISSING_PARAM}
    fi
    USB_DEVICE="$1"
}

require_root() {
    if [[ $(id -u) -ne 0 ]]; then
        log_error "Cette operation necessite les droits root. Utilisez sudo."
        show_help
        exit ${E_NOT_ROOT}
    fi
}

auto_detect_device() {
    local dev
    dev=$(lsblk -dno NAME,TRAN,RM 2>/dev/null \
          | awk '$2=="usb" && $3=="1" {print "/dev/"$1}' \
          | tail -1)
    if [[ -z "${dev}" ]]; then
        log_error "Aucun peripherique USB detecte"
        show_help
        exit ${E_NO_DEVICE}
    fi
    log_info "Peripherique detecte : ${dev}"
    USB_DEVICE="${dev}"
}

print_banner() {
    echo -e "${CYAN}"
    cat <<'EOF'
   _   _ ____  ____   ____       _
  | | | / ___|| __ ) / ___| __ _| |_ ___
  | | | \___ \|  _ \| |  _ / _` | __/ _ \
  | |_| |___) | |_) | |_| | (_| | ||  __/
   \___/|____/|____/ \____|\__,_|\__\___|
EOF
    echo -e "${RESET}"
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

get_scan_mode() {
    if   [[ "${OPT_FORK}"     == true ]]; then echo "fork"
    elif [[ "${OPT_THREAD}"   == true ]]; then echo "thread"
    elif [[ "${OPT_SUBSHELL}" == true ]]; then echo "subshell"
    else                                        echo "normal"
    fi
}

# ============================================================
#  P2 — main()
# ============================================================

main() {
    parse_args "$@"
    init_log

    if [[ "${OPT_RESTORE}" == true ]]; then
        restore_defaults
        exit ${E_OK}
    fi

    require_root
    print_banner

    if [[ "${USB_DEVICE}" == "auto" ]]; then
        auto_detect_device
    fi

    if [[ ! -b "${USB_DEVICE}" ]]; then
        log_error "Peripherique introuvable ou invalide : ${USB_DEVICE}"
        show_help
        exit ${E_NO_DEVICE}
    fi

    log_info "Demarrage USBGate v${USBGATE_VERSION} sur ${USB_DEVICE}"
    mount_usb "${USB_DEVICE}"
    trap 'unmount_usb' EXIT

    scan_with_clamav "${MOUNT_POINT}"

    if [[ "${VIRUS_FOUND}" == true ]]; then
        log_error "VIRUS detecte — import bloque."
        echo -e "\n ${RED}${BOLD}DANGER : Virus detecte. Import bloque.${RESET}\n"
        exit 1
    fi

    scan_all_files "${MOUNT_POINT}" "$(get_scan_mode)"
    show_summary
    interactive_menu
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "${SCRIPT_DIR}/usbgate1.sh" "$@"
