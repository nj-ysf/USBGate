#!/usr/bin/env bash
# ============================================================
#  USBGate - P3
#  Logging, Montage USB et Modes d'Execution
# ============================================================

# ============================================================
#  VARIABLES GLOBALES
# ============================================================

LOG_DIR="/var/log/usbgate"
LOG_FILE="${LOG_DIR}/history.log"

MOUNT_POINT="/mnt/usbgate"

COUNT_SAFE=0
COUNT_MEDIUM=0
COUNT_HIGH=0

# ============================================================
#  CODES D'ERREUR
# ============================================================

E_MOUNT_FAILED=103
E_LOG_FAILED=105

# ============================================================
#  init_log()
#  Initialise le systeme de logs
# ============================================================

init_log() {

    # Utiliser dossier custom si defini via -l
    if [[ -n "${CUSTOM_LOG_DIR}" ]]; then
        LOG_DIR="${CUSTOM_LOG_DIR}"
        LOG_FILE="${LOG_DIR}/history.log"
    fi

    # Creation dossier logs
    mkdir -p "${LOG_DIR}" 2>/dev/null || {
        echo "[ERROR] Impossible de creer le dossier logs" >&2
        exit ${E_LOG_FAILED}
    }

    # Creation fichier log
    touch "${LOG_FILE}" 2>/dev/null || {
        echo "[ERROR] Impossible de creer le fichier log" >&2
        exit ${E_LOG_FAILED}
    }
}

# ============================================================
#  log_info()
#  Affiche INFO terminal + fichier
# ============================================================

log_info() {

    local ts
    ts=$(date '+%Y-%m-%d-%H-%M-%S')

    local user
    user=$(whoami)

    echo "${ts} : ${user} : INFOS : $*" \
        | tee -a "${LOG_FILE}"
}

# ============================================================
#  log_error()
#  Affiche ERROR terminal + fichier
# ============================================================

log_error() {

    local ts
    ts=$(date '+%Y-%m-%d-%H-%M-%S')

    local user
    user=$(whoami)

    echo "${ts} : ${user} : ERROR : $*" \
        | tee -a "${LOG_FILE}" >&2
}

# ============================================================
#  mount_usb()
#  Monte la cle USB en lecture seule
# ============================================================

mount_usb() {

    local device="$1"

    mkdir -p "${MOUNT_POINT}"

    if mount -o ro "${device}" "${MOUNT_POINT}" 2>/dev/null; then

        log_info "Montage reussi en lecture seule : ${MOUNT_POINT}"

    else

        log_error "Echec du montage de ${device}"
        exit ${E_MOUNT_FAILED}

    fi
}

# ============================================================
#  unmount_usb()
#  Demonte proprement la cle USB
# ============================================================

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
#  scan_file()
#  Scan d'un seul fichier
# ============================================================

scan_file() {

    local filepath="$1"

    local filename
    filename=$(basename "${filepath}")

    local risk
    risk=$(classify_file "${filepath}")

    print_risk "${risk}" "${filename}"

    log_info "Scanne : ${filename} -> ${risk}"

    echo "${risk}" >> /tmp/usbgate_results.tmp
}

# ============================================================
#  scan_all_files()
#  Scan complet avec plusieurs modes d'execution
# ============================================================

scan_all_files() {

    local dir="$1"

    local mode="${2:-normal}"

    rm -f /tmp/usbgate_results.tmp

    touch /tmp/usbgate_results.tmp

    # Recuperation de tous les fichiers
    mapfile -t files < <(find "${dir}" -type f 2>/dev/null)

    log_info "Scan mode : ${mode} | Fichiers : ${#files[@]}"

    case "${mode}" in

        # ====================================================
        # MODE NORMAL
        # ====================================================

        normal)

            for f in "${files[@]}"; do
                scan_file "${f}"
            done

        ;;

        # ====================================================
        # MODE FORK
        # ====================================================

        fork)

            for f in "${files[@]}"; do
                (
                    scan_file "${f}"
                ) &
            done

            wait

        ;;

        # ====================================================
        # MODE THREAD
        # ====================================================

        thread)

            local job_count=0

            for f in "${files[@]}"; do

                scan_file "${f}" &

                ((job_count++))

                # Pool de 4 jobs max
                if (( job_count >= 4 )); then
                    wait
                    job_count=0
                fi

            done

            wait

        ;;

        # ====================================================
        # MODE SUBSHELL
        # ====================================================

        subshell)

            (
                for f in "${files[@]}"; do
                    scan_file "${f}"
                done
            )

        ;;

        # ====================================================
        # MODE INVALIDE
        # ====================================================

        *)

            log_error "Mode de scan inconnu : ${mode}"
            return 1

        ;;

    esac

    # ========================================================
    #  CALCUL DES RESULTATS
    # ========================================================

    COUNT_SAFE=$(grep -c "^SAFE$" /tmp/usbgate_results.tmp 2>/dev/null || echo 0)

    COUNT_MEDIUM=$(grep -c "^MEDIUM$" /tmp/usbgate_results.tmp 2>/dev/null || echo 0)

    COUNT_HIGH=$(grep -c "^HIGH$" /tmp/usbgate_results.tmp 2>/dev/null || echo 0)

    log_info "Resultats -> SAFE=${COUNT_SAFE} MEDIUM=${COUNT_MEDIUM} HIGH=${COUNT_HIGH}"
}

