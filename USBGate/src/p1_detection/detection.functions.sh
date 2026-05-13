#!/usr/bin/env bash

# ============================================================
# USBGate - Detection Module (Improved Version)
# Personne 1 : Detection des Menaces
# ============================================================

# ------------------------------------------------------------
# Fallback logging functions if core logger is not loaded
# ------------------------------------------------------------

if ! declare -F log_info >/dev/null; then
    log_info() {
        echo "[INFO] $1"
    }
fi

if ! declare -F log_error >/dev/null; then
    log_error() {
        echo "[ERROR] $1"
    }
fi

if ! declare -F log_warn >/dev/null; then
    log_warn() {
        echo "[WARN] $1"
    }
fi

# ------------------------------------------------------------
# SUSPICIOUS BEHAVIOR SCORING SYSTEM
# SAFE: 0 points
# MEDIUM: 1-2 points
# HIGH: 3+ points
# ------------------------------------------------------------

classify_file() {

    filepath="$1"
    filename=$(basename "$filepath")
    ext="${filename##*.}"
    risk_score=0

    # --------------------------------------------------------
    # CRITERE 1: Double extension
    # --------------------------------------------------------

    if echo "$filename" | grep -qE '\.[a-zA-Z0-9]+\.(exe|sh|bat|elf|vbs|ps1|cmd|scr|pif)$'; then
        echo "HIGH"
        log_warn "Double extension suspecte: $filename"
        return
    fi

    # --------------------------------------------------------
    # CRITERE 2: Nom suspect
    # --------------------------------------------------------

    suspicious_names="svchost.exe|winlogon.exe|lsass.exe|services.exe|explorer.exe"
    suspicious_names="$suspicious_names|csrss.exe|smss.exe|spoolsv.exe|taskmgr.exe"

    normalized_name=$(echo "$filename" | tr '0' 'o' | tr '1' 'l' | tr '5' 's')

    if echo "$normalized_name" | grep -qiE "$suspicious_names"; then
        risk_score=$((risk_score + 2))
        log_warn "Nom de fichier suspect: $filename (+2 points)"
    fi

    # --------------------------------------------------------
    # CRITERE 3: Extensions dangereuses
    # --------------------------------------------------------

    dangerous_ext="exe|msi|scr|pif|com|dll|sys|cpl"

    if echo "$ext" | grep -qiE "^($dangerous_ext)$"; then

        risk_score=$((risk_score + 3))
        log_warn "Executable dangereux: .$ext (+3 points)"

    elif echo "$ext" | grep -qiE '^(sh|elf|bat|vbs|js|ps1|cmd|wsf|vbe|jse)$'; then

        risk_score=$((risk_score + 2))
        log_warn "Script potentiellement dangereux: .$ext (+2 points)"

    elif echo "$ext" | grep -qiE '^(docm|xlsm|pptm|dotm|xlam)$'; then

        risk_score=$((risk_score + 1))
        log_warn "Document avec macros: .$ext (+1 point)"
    fi

    # --------------------------------------------------------
    # CRITERE 4: MIME executable
    # --------------------------------------------------------

    mime=$(file --mime-type -b "$filepath" 2>/dev/null)

    if echo "$mime" | grep -qE 'application/(x-executable|x-sh|x-dosexec|x-msdownload)'; then

        if [[ $risk_score -lt 3 ]] && \
           ! echo "$ext" | grep -qiE "^($dangerous_ext)$"; then

            risk_score=$((risk_score + 2))
            log_warn "MIME type executable suspect (+2 points)"
        fi
    fi

    # --------------------------------------------------------
    # CRITERE 5: Permissions 777
    # --------------------------------------------------------

    perms=$(stat -c "%a" "$filepath" 2>/dev/null)

    if [[ "$perms" == "777" ]]; then
        risk_score=$((risk_score + 1))
        log_warn "Permissions 777 (+1 point)"
    fi

    # --------------------------------------------------------
    # CRITERE 6: Fichiers caches
    # --------------------------------------------------------

    if [[ "$filename" =~ ^\. ]] && \
       [[ "$filename" != "." ]] && \
       [[ "$filename" != ".." ]]; then

        if echo "$filename" | grep -qiE '^\.(DS_Store|localized|Trashes|Spotlight|fseventsd)$'; then

            risk_score=$((risk_score + 1))
            log_warn "Fichier cache systeme: $filename (+1 point)"

        else

            risk_score=$((risk_score + 2))
            log_warn "Fichier cache suspect: $filename (+2 points)"
        fi
    fi

    # --------------------------------------------------------
    # CRITERE 7: Archives
    # --------------------------------------------------------

    if echo "$ext" | grep -qiE '^(zip|rar|tar|gz|7z|iso|bz2|xz)$'; then

        risk_score=$((risk_score + 1))
        log_warn "Archive detectee: .$ext (+1 point)"
    fi

    # --------------------------------------------------------
    # RESULTAT FINAL
    # --------------------------------------------------------

    if [[ $risk_score -ge 3 ]]; then

        echo "HIGH"
        log_warn "Classification HIGH (score: $risk_score) - $filename"

    elif [[ $risk_score -ge 1 ]]; then

        echo "MEDIUM"
        log_info "Classification MEDIUM (score: $risk_score) - $filename"

    else

        echo "SAFE"
        log_info "Classification SAFE - $filename"
    fi
}

# ------------------------------------------------------------
# Detection de noms suspects
# ------------------------------------------------------------

is_suspicious_filename() {

    filename=$(basename "$1")

    suspicious_patterns="(setup|install|crack|keygen|patch|serial|activator|loader)"
    suspicious_patterns="$suspicious_patterns|(free|download|movie|music|game|cracked|hacked)"

    if echo "$filename" | grep -qiE "$suspicious_patterns" && \
       echo "$filename" | grep -qiE '\.(exe|msi|scr|bat|vbs|ps1)$'; then

        return 0
    fi

    return 1
}

# ------------------------------------------------------------
# Scan antivirus ClamAV
# ------------------------------------------------------------

scan_with_clamav() {

    usb_path="$1"

    if ! command -v clamscan >/dev/null 2>&1; then

        log_info "ClamAV n'est pas installe. Scan antivirus ignore."
        VIRUS_FOUND=false
        return 0
    fi

    log_info "Lancement du scan ClamAV sur $usb_path..."

    scan_output=$(clamscan -r --no-summary --infected "$usb_path" 2>&1)
    result=$?

    if echo "$scan_output" | grep -q "FOUND$"; then

        echo "$scan_output" | while read -r line; do

            if echo "$line" | grep -q "FOUND$"; then
                log_error "Virus detecte: $line"
            fi
        done

        VIRUS_FOUND=true

        log_error "Virus detecte ! Import bloque."

        echo "ALERTE ROUGE : un virus a ete trouve."

        return 1
    fi

    if [[ "$result" -eq 0 ]]; then

        VIRUS_FOUND=false

        log_info "Aucun virus detecte."

        return 0

    else

        VIRUS_FOUND=false

        log_error "Erreur pendant le scan ClamAV (code: $result)."

        return 0
    fi
}

# ------------------------------------------------------------
# Analyse supplementaire des signatures
# ------------------------------------------------------------

analyze_file_metadata() {

    filepath="$1"

    magic=$(file -b "$filepath" 2>/dev/null | head -c 50)

    if echo "$magic" | grep -qi "executable" && \
       ! echo "$filepath" | grep -qiE '\.(exe|msi|scr|com)$'; then

        echo "HIGH"

        log_error "Signature executable masquee dans $(basename "$filepath")"

        return
    fi

    classify_file "$filepath"
}

# ------------------------------------------------------------
# Export des fonctions
# ------------------------------------------------------------

export -f classify_file
export -f scan_with_clamav
export -f is_suspicious_filename
export -f analyze_file_metadata
