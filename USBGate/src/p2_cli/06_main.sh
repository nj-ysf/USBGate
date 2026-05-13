#!/usr/bin/env bash
# ============================================================
#  USBGate - P2 - Function 06 : main()
#  Orchestre tout le script dans l'ordre du cahier des charges.
#  Ce module definit main().
#  Le seul point d'entree du projet est usbgate1.sh.
# ============================================================

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

    # --- 4. Afficher la banniere apres validation ---
    print_banner

    # --- 5. Auto-detection si l'utilisateur a tape "auto" ---
    if [[ "${USB_DEVICE}" == "auto" ]]; then
        auto_detect_device    # met a jour la variable globale USB_DEVICE
    fi

    # --- 6. Verifier que le peripherique est bien un block device ---
    if [[ ! -b "${USB_DEVICE}" ]]; then
        log_error "Peripherique introuvable ou invalide : ${USB_DEVICE}"
        show_help
        exit ${E_NO_DEVICE}
    fi

    # --- 7. Monter en lecture seule (P3) ---
    mount_usb "${USB_DEVICE}"

    # --- 8. Filet de securite : demonter automatiquement a la sortie,
    #        meme en cas de Ctrl+C ou d'erreur (trap sur EXIT) ---
    trap 'unmount_usb' EXIT

    # --- 9. Scan antivirus ClamAV (P1) ---
    scan_with_clamav

    # --- 10. Si virus detecte, bloquer l'import ---
    if [[ "${VIRUS_FOUND}" == true ]]; then
        log_error "VIRUS detecte sur la cle - import bloque"
        exit ${E_OK}
    fi

    # --- 11. Scan heuristique de tous les fichiers (P3) ---
    scan_all_files "${MOUNT_POINT}" "$(get_scan_mode)"

    # --- 12. Afficher le resume SAFE/MEDIUM/HIGH (P4) ---
    show_summary

    # --- 13. Menu interactif : import / rapport / quitter (P4) ---
    interactive_menu
}
