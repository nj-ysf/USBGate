#!/usr/bin/env bash
# ============================================================
#  USBGate - Module CLI (Personne 2)
#  Genere automatiquement par build_cli.sh
# ============================================================

# ========= 01_show_help.sh =========
# ============================================================
#  USBGate - P2 - Function 01 : show_help()
#  Affiche l'aide style "man page" Linux.
#  Appelee par -h ET automatiquement apres chaque erreur.
# ============================================================

show_help() {
    # 'cat <<EOF' = "here-document" : on ecrit du texte multi-ligne
    # tel quel, sans avoir besoin de mettre echo a chaque ligne.
    # Les guillemets autour de 'EOF' empechent l'expansion des $variables
    # => le texte reste litteral (plus rapide et plus sur).
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

# ============================================================
#  TEST STANDALONE
#  Cette ligne ne s'execute QUE si le fichier est lance directement
#  (et pas quand il sera "source" depuis cli.sh plus tard).
# ============================================================

# ========= 02_parse_args.sh =========
# ============================================================
#  USBGate - P2 - Function 02 : parse_args()
#  Lit les options CLI avec getopts + valide le parametre device.
# ============================================================

# ---------- VARIABLES GLOBALES (drapeaux d'options) ----------
OPT_FORK=false          # -f : mode fork
OPT_THREAD=false        # -t : mode thread
OPT_SUBSHELL=false      # -s : mode subshell
OPT_RESTORE=false       # -r : restaurer
CUSTOM_LOG_DIR=""       # -l : dossier log custom
USB_DEVICE=""           # parametre obligatoire (device ou "auto")

# ---------- CODES D'ERREUR ----------
E_OK=0
E_BAD_OPTION=100
E_MISSING_PARAM=101

# ============================================================
#  STUBS - remplaces par les vraies fonctions le Jour 3
# ============================================================
if ! declare -F log_error >/dev/null; then
    log_error() {
        echo "$(date '+%Y-%m-%d-%H-%M-%S') : $(whoami) : ERROR : $*" >&2
    }
fi
if ! declare -F show_help >/dev/null; then
    show_help() { echo "[stub show_help]"; }
fi

# ============================================================
#  parse_args() - cœur du parsing CLI
# ============================================================
parse_args() {
    # Reinitialiser OPTIND a chaque appel (important si on appelle 2x)
    OPTIND=1

    # ":hftsl:r"
    #   ":" en debut  -> on gere les erreurs nous-memes (pas de message bash)
    #   "l:"          -> -l attend un argument (stocke dans $OPTARG)
    while getopts ":hftsl:r" opt; do
        case "${opt}" in
            h) show_help; exit ${E_OK} ;;
            f) OPT_FORK=true     ;;
            t) OPT_THREAD=true   ;;
            s) OPT_SUBSHELL=true ;;
            l) CUSTOM_LOG_DIR="${OPTARG}" ;;
            r) OPT_RESTORE=true  ;;

            # Option inconnue -> -z, -x, etc.
            \?)
                log_error "Option inconnue : -${OPTARG}"
                show_help
                exit ${E_BAD_OPTION}
                ;;

            # Option qui manque son argument -> ex: -l sans dossier
            :)
                log_error "Option -${OPTARG} necessite un argument"
                show_help
                exit ${E_BAD_OPTION}
                ;;
        esac
    done

    # Avancer apres les options pour acceder au parametre positionnel
    # ex: "./script.sh -f /dev/sdb1"  =>  apres shift, $1 = "/dev/sdb1"
    shift $((OPTIND - 1))

    # Verifier le parametre obligatoire <device|auto>
    # Sauf si -r : restore n'a pas besoin de device
    if [[ -z "$1" && "${OPT_RESTORE}" == false ]]; then
        log_error "Parametre obligatoire manquant : <device|auto>"
        show_help
        exit ${E_MISSING_PARAM}
    fi

    USB_DEVICE="$1"
}

# ============================================================
#  TEST STANDALONE - affiche les variables apres parsing
# ============================================================

# ========= 03_require_root.sh =========
# ============================================================
#  USBGate - P2 - Function 03 : require_root()
#  Verifie que le script tourne avec les privileges root.
#  Si non root  -> log_error + show_help + exit 102.
# ============================================================

# ---------- CODE D'ERREUR ----------
E_NOT_ROOT=102

# ============================================================
#  STUBS - remplaces le Jour 3 par les vraies fonctions
#  Le "if ! declare -F" evite d'ecraser les vraies si elles existent deja.
# ============================================================
if ! declare -F log_error >/dev/null; then
    log_error() {
        echo "$(date '+%Y-%m-%d-%H-%M-%S') : $(whoami) : ERROR : $*" >&2
    }
fi
if ! declare -F show_help >/dev/null; then
    show_help() { echo "[stub show_help]"; }
fi

# ============================================================
#  require_root() - verification des droits administrateur
# ============================================================
require_root() {
    # 'id -u' renvoie l'UID numerique de l'utilisateur courant.
    # Sur tout systeme Linux/Unix, root = UID 0 (toujours).
    # On compare avec -ne (not equal) en arithmetique.
    if [[ $(id -u) -ne 0 ]]; then
        log_error "Cette operation necessite les droits root. Utilisez sudo."
        show_help
        exit ${E_NOT_ROOT}
    fi

    # Si on arrive ici, c'est qu'on est root. On peut continuer.
    # (pas de "return 0" necessaire : la fonction termine normalement)
}

# ============================================================
#  TEST STANDALONE
# ============================================================

# ========= 04_auto_detect.sh =========
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

# ========= 05_print_banner.sh =========
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

# ========= 06_main.sh =========
# ============================================================
#  USBGate - P2 - Function 06 : main()
#  Orchestre tout le script dans l'ordre du cahier des charges.
#  C'est le seul "point d'entree" appele a la fin du fichier.
# ============================================================

# ---------- VARIABLES GLOBALES ----------
USB_DEVICE=""
MOUNT_POINT="/tmp/usbgate_mount"
LOG_DIR="/var/log/usbgate"
LOG_FILE="${LOG_DIR}/history.log"
CUSTOM_LOG_DIR=""
SAFE_DEST="${HOME}/Downloads/SecureImport"

# ---------- DRAPEAUX D'OPTIONS ----------
OPT_FORK=false
OPT_THREAD=false
OPT_SUBSHELL=false
OPT_RESTORE=false

# ---------- COMPTEURS & ETAT ----------
COUNT_SAFE=0
COUNT_MEDIUM=0
COUNT_HIGH=0
VIRUS_FOUND=false

# ---------- CODES D'ERREUR ----------
E_OK=0
E_BAD_OPTION=100
E_MISSING_PARAM=101
E_NOT_ROOT=102
E_MOUNT_FAIL=103
E_NO_DEVICE=104
E_LOG_FAIL=105
E_RESTORE_DENIED=106

# ============================================================
#  STUBS - remplaces le Jour 3 par les vraies fonctions
#  des autres personnes (P1, P3, P4) + tes propres fonctions.
# ============================================================
if ! declare -F log_info          >/dev/null; then log_info()          { echo "$(date '+%Y-%m-%d-%H-%M-%S') : $(whoami) : INFOS : $*"; }; fi
if ! declare -F log_error         >/dev/null; then log_error()         { echo "$(date '+%Y-%m-%d-%H-%M-%S') : $(whoami) : ERROR : $*" >&2; }; fi
if ! declare -F init_log          >/dev/null; then init_log()          { mkdir -p "${LOG_DIR}" 2>/dev/null && touch "${LOG_FILE}" 2>/dev/null; }; fi
if ! declare -F show_help         >/dev/null; then show_help()         { echo "[stub show_help]"; }; fi
if ! declare -F parse_args        >/dev/null; then parse_args()        { USB_DEVICE="${1:-auto}"; }; fi
if ! declare -F require_root      >/dev/null; then require_root()      { [[ $(id -u) -eq 0 ]] || { log_error "Root requis"; exit 102; }; }; fi
if ! declare -F print_banner      >/dev/null; then print_banner()      { echo "===== USBGate v1.0 ====="; }; fi
if ! declare -F auto_detect_device>/dev/null; then auto_detect_device(){ echo "/dev/loop0"; }; fi
if ! declare -F mount_usb         >/dev/null; then mount_usb()         { log_info "[stub] mount_usb $1"; }; fi
if ! declare -F unmount_usb       >/dev/null; then unmount_usb()       { log_info "[stub] unmount_usb"; }; fi
if ! declare -F scan_with_clamav  >/dev/null; then scan_with_clamav()  { log_info "[stub] scan_with_clamav"; }; fi
if ! declare -F scan_all_files    >/dev/null; then scan_all_files()    { log_info "[stub] scan_all_files dir=$1 mode=$2"; }; fi
if ! declare -F show_summary      >/dev/null; then show_summary()      { log_info "[stub] show_summary"; }; fi
if ! declare -F interactive_menu  >/dev/null; then interactive_menu()  { log_info "[stub] interactive_menu"; }; fi
if ! declare -F restore_defaults  >/dev/null; then restore_defaults()  { log_info "[stub] restore_defaults"; }; fi

# ============================================================
#  Helper - get_scan_mode()
#  Convertit les drapeaux booleens en une chaine de mode.
# ============================================================
get_scan_mode() {
    if   [[ "${OPT_FORK}"     == true ]]; then echo "fork"
    elif [[ "${OPT_THREAD}"   == true ]]; then echo "thread"
    elif [[ "${OPT_SUBSHELL}" == true ]]; then echo "subshell"
    else                                        echo "normal"
    fi
}

# ============================================================
#  main() - le chef d'orchestre
# ============================================================
main() {
    # --- 1. Lire les options et le parametre device ---
    parse_args "$@"

    # --- 2. Initialiser le fichier de log ---
    init_log

    # --- 3. Si -r, restaurer puis quitter immediatement ---
    #     restore_defaults verifie elle-meme les droits root (code 106)
    if [[ "${OPT_RESTORE}" == true ]]; then
        restore_defaults
        exit ${E_OK}
    fi

    # --- 4. Verifier les droits root pour toute autre action ---
    require_root

    # --- 5. Afficher la banniere apres validation ---
    print_banner

    # --- 6. Auto-detection si l'utilisateur a tape "auto" ---
   # --- 6. Auto-detection si l'utilisateur a tape "auto" ---
    if [[ "${USB_DEVICE}" == "auto" ]]; then
        auto_detect_device    # met a jour la variable globale USB_DEVICE
    fi

    # --- 7. Verifier que le peripherique est bien un block device ---
    if [[ ! -b "${USB_DEVICE}" ]]; then
        log_error "Peripherique introuvable ou invalide : ${USB_DEVICE}"
        show_help
        exit ${E_NO_DEVICE}
    fi

    # --- 8. Monter en lecture seule (P3) ---
    mount_usb "${USB_DEVICE}"

    # --- 9. Filet de securite : demonter automatiquement a la sortie,
    #        meme en cas de Ctrl+C ou d'erreur (trap sur EXIT) ---
    trap 'unmount_usb' EXIT

    # --- 10. Scan antivirus ClamAV (P1) ---
    scan_with_clamav

    # --- 11. Si virus detecte, bloquer l'import ---
    if [[ "${VIRUS_FOUND}" == true ]]; then
        log_error "VIRUS detecte sur la cle - import bloque"
        exit ${E_OK}
    fi

    # --- 12. Scan heuristique de tous les fichiers (P3) ---
    scan_all_files "${MOUNT_POINT}" "$(get_scan_mode)"

    # --- 13. Afficher le resume SAFE/MEDIUM/HIGH (P4) ---
    show_summary

    # --- 14. Menu interactif : import / rapport / quitter (P4) ---
    interactive_menu
}

# ============================================================
#  POINT D'ENTREE
#  Le "$@" passe TOUS les arguments du script a main().
# ============================================================
main "$@"
main "$@"
