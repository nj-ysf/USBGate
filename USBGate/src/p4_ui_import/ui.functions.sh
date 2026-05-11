#!/usr/bin/env bash
# ============================================================
#  USBGate - P4 : Interface, Import, Rapport et Restauration
#  Fonctions : print_risk, show_summary, interactive_menu,
#              import_safe_files, generate_report, restore_defaults
# ============================================================

# ---------- COULEURS (reprises de P2 pour homogeneite) ----------
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

# ---------- VALEURS PAR DEFAUT (surchargees par main) ----------
MOUNT_POINT="${MOUNT_POINT:-/tmp/usbgate_mount}"
SAFE_DEST="${SAFE_DEST:-$HOME/Downloads/SecureImport}"
USB_DEVICE="${USB_DEVICE:-}"

# ---------- CODES D'ERREUR ----------
E_RESTORE_DENIED=106

# ============================================================
#  print_risk()
#  Affiche un fichier colore selon son niveau de risque.
#  Appelee par scan_file() (P3) pour chaque fichier.
#  $1 = niveau (SAFE|MEDIUM|HIGH)
#  $2 = nom du fichier
# ============================================================

print_risk() {
    local level="$1"
    local name="$2"

    case "${level}" in
        SAFE)
            echo -e " [${GREEN}SAFE   ${RESET}] ${name}"
            ;;
        MEDIUM)
            echo -e " [${YELLOW}MEDIUM ${RESET}] ${name}"
            ;;
        HIGH)
            echo -e " [${RED}HIGH   ${RESET}] ${name}"
            ;;
    esac
}

# ============================================================
#  show_summary()
#  Affiche un tableau recapitulatif SAFE/MEDIUM/HIGH.
#  Utilise les variables globales COUNT_SAFE, COUNT_MEDIUM,
#  COUNT_HIGH peuplees par scan_all_files() (P3).
#  Enregistre le resume dans le log via log_info().
# ============================================================

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
        local padding=$((inner_width - ${#inner}))
        [[ $padding -lt 0 ]] && padding=0
        echo -e " ║${colors[$i]}${inner}$(printf '%*s' $padding)${RESET}║"
    done

    echo " ╚══════════════════════════════════════════╝"
    log_info "Resume : SAFE=${COUNT_SAFE} MEDIUM=${COUNT_MEDIUM} HIGH=${COUNT_HIGH}"
}

# ============================================================
#  interactive_menu()
#  Menu utilisateur avec 3 choix :
#    1) Copier les fichiers SAFE
#    2) Generer un rapport detaille
#    3) Quitter et demonter
#  Boucle jusqu'a ce que l'utilisateur choisisse 3.
# ============================================================

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
            1)
                import_safe_files
                ;;
            2)
                generate_report
                ;;
            3)
                log_info "Sortie utilisateur demandee"
                echo -e "\n ${GREEN}Demonter la cle USB et fin du programme.${RESET}"
                return
                ;;
            *)
                echo -e " ${YELLOW}Choix invalide. Veuillez entrer 1, 2 ou 3.${RESET}"
                ;;
        esac
    done
}

# ============================================================
#  import_safe_files()
#  Copie tous les fichiers classes SAFE vers ~/Downloads/SecureImport/.
#  Utilise find + classify_file() pour filtrer.
#  Concepts : cp, mkdir, find, boucle while, log_info.
# ============================================================

import_safe_files() {
    mkdir -p "${SAFE_DEST}" 2>/dev/null || {
        log_error "Impossible de creer le dossier ${SAFE_DEST}"
        return 1
    }

    local copied=0
    local total=0

    while IFS= read -r -d "" filepath; do
        (( total++ ))
        local risk
        risk=$(classify_file "${filepath}")
        if [[ "${risk}" == "SAFE" ]]; then
            cp "${filepath}" "${SAFE_DEST}/" 2>/dev/null && (( copied++ ))
        fi
    done < <(find "${MOUNT_POINT}" -type f -print0 2>/dev/null)

    echo ""
    echo -e " ${GREEN}${copied} fichier(s) SAFE copie(s) sur ${total} fichier(s) total${RESET}"
    echo -e " ${CYAN}Destination : ${SAFE_DEST}${RESET}"
    log_info "Import termine : ${copied} fichier(s) SAFE copies vers ${SAFE_DEST}"
}

# ============================================================
#  generate_report()
#  Cree un rapport texte avec tee (terminal + fichier),
#  le compresse avec gzip.
#  Concepts : tee, sort, find, gzip, log_info.
# ============================================================

generate_report() {
    local report
    report="/tmp/usbgate_report_$(date '+%Y%m%d_%H%M%S').txt"

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
            local relpath="${f#${MOUNT_POINT}/}"
            local risk
            risk=$(classify_file "${f}")
            echo " [${risk}] ${relpath}"
        done
        echo ""
        echo "--- FIN DU RAPPORT ---"
    } | tee "${report}"

    gzip "${report}" 2>/dev/null && {
        log_info "Rapport genere : ${report}.gz"
        echo ""
        echo -e " ${CYAN}Rapport compresse : ${report}.gz${RESET}"
    } || {
        log_error "Echec de la compression du rapport"
    }
}

# ============================================================
#  restore_defaults()
#  Option -r : restaure les parametres par defaut.
#  ROOT UNIQUEMENT (verification par id -u, code 106 si refuse).
#  Actions : demonte la cle, vide le log, supprime SecureImport
#            et les fichiers temporaires.
# ============================================================

restore_defaults() {
    if [[ $(id -u) -ne 0 ]]; then
        log_error "L'option -r necessite les droits root (administrateur)."
        exit ${E_RESTORE_DENIED}
    fi

    log_info "Restauration des parametres par defaut..."

    # 1. Demonter la cle si montee
    if declare -F unmount_usb >/dev/null; then
        unmount_usb
    fi

    # 2. Vider le fichier de log
    > "${LOG_FILE}" 2>/dev/null

    # 3. Supprimer le dossier d'import securise
    rm -rf "${SAFE_DEST}" 2>/dev/null

    # 4. Supprimer les fichiers temporaires
    rm -f /tmp/usbgate_* 2>/dev/null

    log_info "Restauration terminee. Tous les parametres remis a zero."
}

