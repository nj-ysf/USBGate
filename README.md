# USBGate
### Secure USB Device Analysis & Controlled Import System

USBGate is a Linux-based USB security framework developed entirely in Bash Shell.

The project was designed to analyze USB storage devices before allowing file importation into the system. It combines file inspection, suspicious behavior detection, secure mounting, logging, and antivirus scanning in order to reduce risks caused by malicious USB devices.

The system focuses on lightweight security automation using native Linux tools and modular shell scripting.

---

# Project Objectives

Modern USB devices can carry:
- malware
- hidden executables
- malicious scripts
- dangerous archives
- disguised files

USBGate aims to:
- automatically detect USB devices
- securely mount them
- scan their contents
- classify files according to risk level
- block suspicious imports
- generate execution logs
- provide multiple execution modes for performance experimentation

---

# Main Features

## USB Management
- automatic USB detection
- manual device selection
- secure mounting system
- automatic cleanup and restoration

## File Threat Detection
- dangerous extension detection
- double extension detection (`photo.jpg.exe`)
- executable MIME analysis
- suspicious hidden file detection
- suspicious filename heuristics
- dangerous permission analysis
- archive detection
- metadata inspection

## Antivirus Integration
- ClamAV support
- recursive malware scan
- infected file reporting
- automatic import blocking

## Execution Modes
- fork mode
- parallel jobs/thread-like mode
- subshell mode

## Logging System
- activity history
- warnings
- errors
- scan reports
- execution tracing

---

# Technologies Used

## Languages
- Bash Shell

## Linux Utilities
- grep
- awk
- stat
- file
- find
- mount
- lsblk
- chmod
- basename

## Security Tools
- ClamAV

## Environment
- Ubuntu Linux
- VirtualBox
- WSL (testing)

---

# Project Structure

```text
USBGate/
├── docs/
│   ├── division_du_travail.md
│   └── exit_codes.md
│
├── log/
│   └── history.log
│
├── src/
│   ├── p1_detection/
│   │   ├── detection.functions.sh
│   │   └── detection.sh
│   │
│   ├── p2_cli/
│   │   ├── 01_show_help.sh
│   │   ├── 02_parse_args.sh
│   │   ├── 03_require_root.sh
│   │   ├── 04_auto_detect.sh
│   │   ├── 05_print_banner.sh
│   │   ├── 06_main.sh
│   │   ├── build_cli.sh
│   │   ├── cli.functions.sh
│   │   └── cli.sh
│   │
│   ├── p3_core/
│   │   ├── core.functions.sh
│   │   └── core.sh
│   │
│   └── p4_ui_import/
│       ├── README.md
│       ├── ui.functions.sh
│       └── ui.sh
│
├── tests/
│   ├── benchmark_modes.sh
│   └── create_test_usb.sh
│
├── .gitignore
├── README.md
└── usbgate.sh
