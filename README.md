# USBGate

USBGate is a Bash project that secures USB key usage.

This part contains the threat detection functions:

- classify_file()
- scan_with_clamav()

## How to run

```bash
source detection.sh
classify_file /path/to/file
