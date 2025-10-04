#!/usr/bin/env bash
set -euo pipefail
# Install git depending on distribution family (Debian vs RHEL)
# Ensure /etc/os-release exists. On very minimal systems it can be missing; try to create it.
if [ ! -f /etc/os-release ]; then
    echo "/etc/os-release not found; attempting to provision it..."
    # detect package manager and try to install lsb-release (provides lsb_release)
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq || true
        apt-get install -y -qq lsb-release || true
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y -q redhat-lsb-core || true
    elif command -v yum >/dev/null 2>&1; then
        yum install -y -q redhat-lsb-core || true
    fi
    # If lsb_release is available, synthesize /etc/os-release from its output
    if command -v lsb_release >/dev/null 2>&1; then
        echo "Generating /etc/os-release from lsb_release"
        cat > /etc/os-release <<EOF
NAME="$(lsb_release -si)"
VERSION_ID="$(lsb_release -sr)"
ID="$(lsb_release -si | tr '[:upper:]' '[:lower:]')"
PRETTY_NAME="$(lsb_release -sd)"
EOF
    else
        # Fallback: create a minimal /etc/os-release using uname
        echo "Creating minimal /etc/os-release from uname"
        cat > /etc/os-release <<EOF
NAME="$(uname -s)"
VERSION="$(uname -r)"
ID="$(uname -s | tr '[:upper:]' '[:lower:]')"
PRETTY_NAME="$(uname -s) $(uname -r)"
EOF
    fi
fi
if [ -f /etc/os-release ]; then
    . /etc/os-release
    # prefer ID, fall back to ID_LIKE
    family="${ID_LIKE:-$ID}"
    if [[ "${ID}" =~ ^(debian|ubuntu)$ ]] || [[ "${family}" =~ debian ]]; then
        apt-get update -qq
        apt-get install -y -qq git
    elif [[ "${ID}" =~ ^(centos|rhel|rocky|almalinux|fedora)$ ]] || [[ "${family}" =~ (rhel|fedora|centos) ]]; then
        if command -v dnf >/dev/null 2>&1; then
            dnf install -y -q git
        else
            yum install -y -q git
        fi
    else
        # fallback: try common package managers
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update -qq
            apt-get install -y git
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y git
        elif command -v yum >/dev/null 2>&1; then
            yum install -y git
        else
            echo "No supported package manager found to install git" >&2
            exit 1
        fi
    fi
else
    echo "/etc/os-release not found; cannot detect distribution to install git" >&2
    exit 1
fi
if [ -d glpi_install ]; then 
    cd glpi_install
    git reset --hard
    git pull origin dev
    cd ..
else 
    git clone https://github.com/Papy-Poc/glpi_install.git -b dev
fi
chmod -R +x ~/glpi_install
~/glpi_install/glpi-install

