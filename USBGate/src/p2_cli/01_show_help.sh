#!/usr/bin/env bash
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
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && show_help