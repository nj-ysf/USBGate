#!/usr/bin/env bash
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
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"

    echo "------ Resultat du parsing ------"
    echo "OPT_FORK       = ${OPT_FORK}"
    echo "OPT_THREAD     = ${OPT_THREAD}"
    echo "OPT_SUBSHELL   = ${OPT_SUBSHELL}"
    echo "OPT_RESTORE    = ${OPT_RESTORE}"
    echo "CUSTOM_LOG_DIR = '${CUSTOM_LOG_DIR}'"
    echo "USB_DEVICE     = '${USB_DEVICE}'"
fi