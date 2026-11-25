#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Help
# ============================================================

show_help() {
cat <<EOF
Usage:
  $0 --lan <interface> --wan <interface> --mgmt <interface>

Examples:

  $0 --lan eth0 --wan eth1 --mgmt eno1

  $0 --lan lan --wan wan --mgmt mgmt

Options:
  --lan     LAN interface
  --wan     WAN interface
  --mgmt    Management interface
  -h        Show help
  --help    Show help
EOF
}

(( $# > 0 )) || {
    show_help
    exit 1
}

# ============================================================
# Parse arguments
# ============================================================

LAN=""
WAN=""
MGMT=""

while (( $# > 0 )); do
    case "$1" in
        --lan)
            (( $# >= 2 )) || {
                echo "[-] Missing value for --lan" >&2
                exit 1
            }
            LAN="$2"
            shift 2
            ;;
        --wan)
            (( $# >= 2 )) || {
                echo "[-] Missing value for --wan" >&2
                exit 1
            }
            WAN="$2"
            shift 2
            ;;
        --mgmt)
            (( $# >= 2 )) || {
                echo "[-] Missing value for --mgmt" >&2
                exit 1
            }
            MGMT="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "[-] Unknown parameter: $1" >&2
            echo
            show_help
            exit 1
            ;;
    esac
done

: "${LAN:?Missing --lan parameter}"
: "${WAN:?Missing --wan parameter}"
: "${MGMT:?Missing --mgmt parameter}"

readonly LAN WAN MGMT

# ============================================================
# Configuration
# ============================================================

readonly INSTALLDIR="/opt/gateway"
readonly SCRIPTSDIR="${INSTALLDIR}/scripts"
readonly FWPATH="/etc/profile.d/fw-path.sh"
readonly FWENV="/etc/profile.d/fw-env.sh"

# ============================================================
# Root check
# ============================================================

if (( EUID != 0 )); then
    echo "[-] This script must be run as root." >&2
    exit 1
fi

# ============================================================
# Functions
# ============================================================

interface_exists() {
    ip link show "$1" >/dev/null 2>&1
}

validate_interfaces() {

    interface_exists "$LAN" || {
        echo "[-] Interface '$LAN' not found"
        exit 1
    }

    interface_exists "$WAN" || {
        echo "[-] Interface '$WAN' not found"
        exit 1
    }

    interface_exists "$MGMT" || {
        echo "[-] Interface '$MGMT' not found"
        exit 1
    }

    [[ "$LAN" != "$WAN" ]] || {
        echo "[-] LAN and WAN cannot be the same interface"
        exit 1
    }

    [[ "$LAN" != "$MGMT" ]] || {
        echo "[-] LAN and MGMT cannot be the same interface"
        exit 1
    }

    [[ "$WAN" != "$MGMT" ]] || {
        echo "[-] WAN and MGMT cannot be the same interface"
        exit 1
    }
}

validate_scripts() {

    local file

    for file in fw.sh fwfunctions; do

        [[ -f "$file" ]] || {
            echo "[-] Missing file: $file"
            exit 1
        }

        if ! bash -n "$file"; then
            echo "[-] Syntax check failed: $file"
            exit 1
        fi

    done

    [[ -f fw.conf ]] || {
        echo "[-] Missing file: fw.conf"
        exit 1
    }

    if command -v shellcheck >/dev/null 2>&1; then
        echo "[*] Running shellcheck..."
        shellcheck -x -P . -a fw.sh
    fi

    echo "[+] Script validation passed"
}

install_firewall_files() {

    install -D -m 755 fw.sh \
        "${SCRIPTSDIR}/fw.sh"

    install -D -m 644 fw.conf \
        "${SCRIPTSDIR}/fw.conf"

    install -D -m 644 fwfunctions \
        "${SCRIPTSDIR}/fwfunctions"

    echo "[+] Firewall files installed"
}

configure_environment() {

    cat >"${FWPATH}" <<EOF
export PATH=\$PATH:${SCRIPTSDIR}
EOF

    chmod 644 "${FWPATH}"

    cat >"${FWENV}" <<EOF
export WAN=${WAN}
export LAN=${LAN}
export MGMT=${MGMT}
EOF

    chmod 644 "${FWENV}"

    export PATH="$PATH:${SCRIPTSDIR}"

    echo "[+] Created "${FWPATH}""
    echo "[+] Created ${FWENV}"
}

# ============================================================
# Main
# ============================================================

echo "=== Validating interfaces ==="

validate_interfaces

echo
echo "WAN  : $WAN"
echo "LAN  : $LAN"
echo "MGMT : $MGMT"
echo

echo "=== Validating scripts ==="

validate_scripts

echo
echo "=== Installing firewall files ==="

install_firewall_files

echo
echo "=== Configuring environment ==="

configure_environment

echo
echo "========================================"
echo "Installation completed successfully."
echo
echo "Configured interfaces:"
echo "  WAN  = $WAN"
echo "  LAN  = $LAN"
echo "  MGMT = $MGMT"
echo
echo "Environment files:"
echo "  ${FWPATH}"
echo "  ${FWENV}"
echo
echo "Firewall configuration:"
echo "  ${SCRIPTSDIR}/fw.conf"
echo "========================================"
