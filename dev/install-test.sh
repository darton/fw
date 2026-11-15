#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Help
# ============================================================

show_help() {
cat <<EOF
Usage:
  $0 --lan <iface|mac> --wan <iface|mac> --mgmt <iface|mac>

Examples:

  $0 --lan eth0 --wan eth1 --mgmt eno1

  $0 \\
     --lan 00:11:22:33:44:55 \\
     --wan aa:bb:cc:dd:ee:ff \\
     --mgmt 12:34:56:78:90:ab

Options:
  --lan     LAN interface name or MAC address
  --wan     WAN interface name or MAC address
  --mgmt    Management interface name or MAC address
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

is_mac() {
    [[ "$1" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]]
}

get_mac() {

    local target="$1"

    if is_mac "$target"; then
        printf '%s\n' "${target,,}"
        return 0
    fi

    [[ -r "/sys/class/net/$target/address" ]] || {
        echo "[-] Interface '$target' not found" >&2
        return 1
    }

    tr '[:upper:]' '[:lower:]' < "/sys/class/net/$target/address"
}

validate_interfaces() {

    local lan_mac wan_mac mgmt_mac

    lan_mac=$(get_mac "$LAN")
    wan_mac=$(get_mac "$WAN")
    mgmt_mac=$(get_mac "$MGMT")

    LAN_MAC="$lan_mac"
    WAN_MAC="$wan_mac"
    MGMT_MAC="$mgmt_mac"

    readonly LAN_MAC WAN_MAC MGMT_MAC

    [[ "$LAN_MAC" != "$WAN_MAC" ]] || {
        echo "[-] LAN and WAN refer to the same interface (MAC: $LAN_MAC)"
        exit 1
    }

    [[ "$LAN_MAC" != "$MGMT_MAC" ]] || {
        echo "[-] LAN and MGMT refer to the same interface (MAC: $LAN_MAC)"
        exit 1
    }

    [[ "$WAN_MAC" != "$MGMT_MAC" ]] || {
        echo "[-] WAN and MGMT refer to the same interface (MAC: $WAN_MAC)"
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
        shellcheck fw.sh fwfunctions
    fi

    echo "[+] Bash syntax validation passed"
}

check_altname_conflict() {

    local altname="$1"
    local expected_file="/etc/systemd/network/10-${altname}.link"
    local found_file

    while IFS= read -r found_file; do

        [[ "$found_file" == "$expected_file" ]] && continue

        if grep -Eq "^[[:space:]]*AlternativeName=${altname}$" "$found_file"; then
            echo "[-] AlternativeName '${altname}' already exists:"
            echo "    $found_file"
            exit 1
        fi

    done < <(
        find /etc/systemd/network \
             -maxdepth 1 \
             -type f \
             -name '*.link' \
             2>/dev/null
    )
}

configure_altname() {

    local mac="$1"
    local altname="$2"
    local link_file="/etc/systemd/network/10-${altname}.link"

    mkdir -p /etc/systemd/network

    check_altname_conflict "$altname"

    cat >"$link_file" <<EOF
[Match]
MACAddress=${mac}

[Link]
AlternativeName=${altname}
EOF

    echo "[+] Configured ${mac} -> ${altname}"
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

    cat >/etc/profile.d/gateway-path.sh <<EOF
export PATH=\$PATH:${SCRIPTSDIR}
EOF

    chmod 644 /etc/profile.d/gateway-path.sh

    cat >/etc/profile.d/gateway-env.sh <<EOF
export GATEWAY_HOME=${INSTALLDIR}
export GATEWAY_SCRIPTS=${SCRIPTSDIR}
export GATEWAY_CONF=${SCRIPTSDIR}/fw.conf

export WAN=wan
export LAN=lan
export MGMT=mgmt

export WAN_MAC=${WAN_MAC}
export LAN_MAC=${LAN_MAC}
export MGMT_MAC=${MGMT_MAC}
EOF

    chmod 644 /etc/profile.d/gateway-env.sh

    export PATH="$PATH:${SCRIPTSDIR}"

    echo "[+] Created /etc/profile.d/gateway-path.sh"
    echo "[+] Created /etc/profile.d/gateway-env.sh"
}

# ============================================================
# Main
# ============================================================

echo "=== Validating interfaces ==="

validate_interfaces

echo
echo "LAN  : $LAN  ($LAN_MAC)"
echo "WAN  : $WAN  ($WAN_MAC)"
echo "MGMT : $MGMT ($MGMT_MAC)"
echo

echo "=== Validating scripts ==="

validate_scripts

echo
echo "=== Configuring interface aliases ==="

configure_altname "$WAN_MAC"  "wan"
configure_altname "$LAN_MAC"  "lan"
configure_altname "$MGMT_MAC" "mgmt"

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
echo "Configured alternative interface names:"
echo "  wan  -> $WAN_MAC"
echo "  lan  -> $LAN_MAC"
echo "  mgmt -> $MGMT_MAC"
echo
echo "Environment files:"
echo "  /etc/profile.d/gateway-path.sh"
echo "  /etc/profile.d/gateway-env.sh"
echo
echo "Firewall configuration:"
echo "  ${SCRIPTSDIR}/fw.conf"
echo
echo "Reboot the system to activate interface aliases."
echo "========================================"

