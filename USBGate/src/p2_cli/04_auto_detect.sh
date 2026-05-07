#!/usr/bin/env bash
# ============================================================
#  USBGate - P2 - Function 04 : auto_detect_device()
#  Detecte automatiquement la 1ere cle USB connectee.
#  Utilise le pipeline obligatoire : lsblk | awk | tail
# ============================================================

# ---------- CODE D'ERREUR ----------
E_NO_DEVICE=104

# ============================================================
#  STUBS (avec garde anti-conflit)
# ============================================================
if ! declare -F log_info >/dev/null; then
    log_info()  { echo "$(date '+%Y-%m-%d-%H-%M-%S') : $(whoami) : INFOS : $*"; }
fi
if ! declare -F log_error >/dev/null; then
    log_error() { echo "$(date '+%Y-%m-%d-%H-%M-%S') : $(whoami) : ERROR : $*" >&2; }
fi
if ! declare -F show_help >/dev/null; then
    show_help() { echo "[stub show_help]"; }
fi

# ============================================================
#  auto_detect_device() - retourne le chemin d'une USB via stdout
# ============================================================
auto_detect_device() {
    # ----- Le pipeline (cahier des charges §3.2.2) -----
    #
    # lsblk -dno NAME,TRAN,RM
    #    -d : seulement les disques (pas les partitions sda1, sda2...)
    #    -n : pas d'en-tete (juste les donnees)
    #    -o : colonnes voulues
    #         NAME = nom du device (ex: sdb)
    #         TRAN = transport bus (ex: usb, sata, nvme)
    #         RM   = removable (1 = amovible, 0 = fixe)
    #
    # awk '$2=="usb" && $3=="1" {print "/dev/"$1}'
    #    Ne garde que les lignes ou TRAN=usb ET RM=1.
    #    Affiche le chemin complet : sdb -> /dev/sdb
    #
    # tail -1
    #    Si plusieurs USB connectees, prend la derniere (la plus recente).
    #
   
    local dev
    dev=$(lsblk -dno NAME,TRAN,RM 2>/dev/null \
          | awk '$2=="usb" && $3=="1" {print "/dev/"$1}' \
          | tail -1)

    if [[ -z "${dev}" ]]; then
        log_error "Aucun peripherique USB detecte"
        show_help >&2
        exit ${E_NO_DEVICE}
    fi

    log_info "Peripherique detecte : ${dev}" >&2   # log to stderr so it doesn't pollute stdout
    USB_DEVICE="${dev}"                            # set the global directly (no $() needed)

}

# ============================================================
#  TEST STANDALONE
# ============================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "------ Listing complet de lsblk ------"
    lsblk -o NAME,TRAN,RM,SIZE,MOUNTPOINT
    echo ""
    echo "------ Detection auto USB ------"
    detected=$(auto_detect_device)
    echo "Resultat : ${detected}"
fi  