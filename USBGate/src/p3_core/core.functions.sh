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

RESULT_FILE="/tmp/usbgate_results.tmp"
LOCK_FILE="/tmp/usbgate.lock"

COUNT_SAFE=0
COUNT_MEDIUM=0
COUNT_HIGH=0

MAX_WORKERS=4

# ============================================================
#  CODES D'ERREUR
# ============================================================

E_MOUNT_FAILED=103
E_LOG_FAILED=105

# ============================================================
#  init_log()
# ============================================================

init_log() {

    if [[ -n "${CUSTOM_LOG_DIR}" ]]; then
        LOG_DIR="${CUSTOM_LOG_DIR}"
        LOG_FILE="${LOG_DIR}/history.log"
    fi

    mkdir -p "${LOG_DIR}" 2>/dev/null || {
        echo "[ERROR] Impossible de creer le dossier logs" >&2
        exit ${E_LOG_FAILED}
    }

    touch "${LOG_FILE}" 2>/dev/null || {
        echo "[ERROR] Impossible de creer le fichier log" >&2
        exit ${E_LOG_FAILED}
    }
}

# ============================================================
#  log_info()
# ============================================================

log_info() {

    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')

    local user
    user=$(whoami)

    echo "${ts} : ${user} : INFO : $*" \
        | tee -a "${LOG_FILE}"
}

# ============================================================
#  log_error()
# ============================================================

log_error() {

    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')

    local user
    user=$(whoami)

    echo "${ts} : ${user} : ERROR : $*" \
        | tee -a "${LOG_FILE}" >&2
}

# ============================================================
#  mount_usb()
# ============================================================

mount_usb() {

    local device="$1"

    mkdir -p "${MOUNT_POINT}"

    if mount -o ro "${device}" "${MOUNT_POINT}" 2>/dev/null; then

        log_info "Montage reussi : ${MOUNT_POINT}"

    else

        log_error "Echec du montage : ${device}"
        exit ${E_MOUNT_FAILED}

    fi
}

# ============================================================
#  unmount_usb()
# ============================================================

unmount_usb() {

    if mountpoint -q "${MOUNT_POINT}" 2>/dev/null; then

        umount "${MOUNT_POINT}" 2>/dev/null

        rmdir "${MOUNT_POINT}" 2>/dev/null

        log_info "Cle USB demontee"

    else

        log_info "Aucun montage actif"

    fi
}

# ============================================================
#  save_result()
#  Protection contre race condition
# ============================================================

save_result() {

    local risk="$1"

    {
        flock -x 200
        echo "${risk}" >> "${RESULT_FILE}"
    } 200>"${LOCK_FILE}"
}

# ============================================================
#  scan_file()
# ============================================================

scan_file() {

    local filepath="$1"

    local filename
    filename=$(basename "${filepath}")

    local risk
    risk=$(classify_file "${filepath}")

    print_risk "${risk}" "${filename}"

    log_info "Scanne : ${filename} -> ${risk}"

    save_result "${risk}"
}

# ============================================================
#  worker_pool_wait()
#  Limite nombre jobs paralleles
# ============================================================

worker_pool_wait() {

    while (( $(jobs -r | wc -l) >= MAX_WORKERS )); do
        sleep 0.1
    done
}

# ============================================================
#  scan_all_files()
# ============================================================

scan_all_files() {

    local dir="$1"
    local mode="${2:-normal}"

    rm -f "${RESULT_FILE}" "${LOCK_FILE}"

    touch "${RESULT_FILE}"

    mapfile -t files < <(
        find "${dir}" -type f 2>/dev/null
    )

    log_info "Mode scan : ${mode}"
    log_info "Fichiers detectes : ${#files[@]}"

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
                scan_file "${f}" &
            done

            wait

        ;;

        # ====================================================
        # MODE THREAD
        # ====================================================

        thread)

            for f in "${files[@]}"; do

                worker_pool_wait

                scan_file "${f}" &

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

            log_error "Mode invalide : ${mode}"
            return 1

        ;;

    esac

    # ========================================================
    #  RESULTATS
    # ========================================================

    COUNT_SAFE=$(grep -c "^SAFE$" "${RESULT_FILE}" 2>/dev/null || echo 0)

    COUNT_MEDIUM=$(grep -c "^MEDIUM$" "${RESULT_FILE}" 2>/dev/null || echo 0)

    COUNT_HIGH=$(grep -c "^HIGH$" "${RESULT_FILE}" 2>/dev/null || echo 0)

    log_info "========================================"
    log_info "SAFE   : ${COUNT_SAFE}"
    log_info "MEDIUM : ${COUNT_MEDIUM}"
    log_info "HIGH   : ${COUNT_HIGH}"
    log_info "========================================"
}