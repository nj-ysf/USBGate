#!/usr/bin/env bash

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

classify_file() {
    filepath="$1"
    filename=$(basename "$filepath")
    ext="${filename##*.}"

    # Detect double dangerous extension
    if echo "$filename" | grep -qE '\.[a-zA-Z]+\.(exe|sh|bat|elf|vbs)$'; then
        echo "HIGH"
        return
    fi

    # Detect dangerous extensions
    if echo "$ext" | grep -qE '^(exe|sh|elf|bat|vbs|jar|ps1|cmd)$'; then
        echo "HIGH"
        return
    fi

    # Detect executable MIME type
    mime=$(file --mime-type -b "$filepath")
    if echo "$mime" | grep -qE 'application/(x-executable|x-sh|x-dosexec)'; then
        echo "HIGH"
        return
    fi

    # Detect executable permission
    if [[ -x "$filepath" ]]; then
        echo "HIGH"
        return
    fi

    # Detect 777 permissions
    perms=$(stat -c "%a" "$filepath")
    if [[ "$perms" == "777" ]]; then
        echo "HIGH"
        return
    fi

    # Detect hidden files
    if [[ "$filename" == .* ]]; then
        echo "MEDIUM"
        return
    fi

    # Detect archives
    if echo "$ext" | grep -qE '^(zip|rar|tar|gz|7z|iso)$'; then
        echo "MEDIUM"
        return
    fi

    echo "SAFE"
}

scan_with_clamav() {
    usb_path="$1"

    # Check if ClamAV is installed
    if ! command -v clamscan >/dev/null 2>&1; then
        log_info "ClamAV n'est pas installé. Scan antivirus ignoré."
        VIRUS_FOUND=false
        return
    fi

    # Run antivirus scan
    clamscan -r --bell "$usb_path"
    result=$?

    if [[ "$result" -eq 1 ]]; then
        VIRUS_FOUND=true
        log_error "Virus détecté ! Import bloqué."
        echo "ALERTE ROUGE : un virus a été trouvé."
    elif [[ "$result" -eq 0 ]]; then
        VIRUS_FOUND=false
        log_info "Aucun virus détecté."
    else
        VIRUS_FOUND=false
        log_error "Erreur pendant le scan ClamAV."
    fi
}
