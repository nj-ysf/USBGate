#!/usr/bin/env bash
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
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "UID actuel : $(id -u)  (utilisateur : $(whoami))"
    require_root
    echo "✓ Root confirme - le script peut continuer"
fi