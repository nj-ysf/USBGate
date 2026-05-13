#!/usr/bin/env bash
# ============================================================
#  Builder - assemble les 6 files de P2 en un seul cli.sh
#  Ordre important : les fonctions doivent etre definies AVANT
#  les fonctions qui les appellent.
# ============================================================

OUT="cli.sh"

cat > "${OUT}" <<'HEADER'
#!/usr/bin/env bash
# ============================================================
#  USBGate - Module CLI (Personne 2)
#  Genere automatiquement par build_cli.sh
# ============================================================

HEADER

# Ordre de concatenation :
# 1. Banniere d'aide  (utilisee partout)l
# 2. parse_args       (utilise show_help + log_error)
# 3. require_root     (utilise log_error + show_help)
# 4. auto_detect      (utilise log_info + log_error + show_help)
# 5. print_banner     (utilise USB_DEVICE + LOG_FILE)
# 6. main             (utilise tout le reste)

for f in 01_show_help.sh \
         02_parse_args.sh \
         03_require_root.sh \
         04_auto_detect.sh \
         05_print_banner.sh \
         06_main.sh; do
    echo "# ========= ${f} =========" >> "${OUT}"

    # Retire le shebang et le bloc de test standalone de chaque file
    sed -e '/^#!\/usr\/bin\/env bash/d' \
        -e '/BASH_SOURCE\[0\]/,$d' \
        "${f}" >> "${OUT}"

    echo "" >> "${OUT}"
done

chmod +x "${OUT}"
echo "✓ ${OUT} genere comme module ($(wc -l < "${OUT}") lignes)"
