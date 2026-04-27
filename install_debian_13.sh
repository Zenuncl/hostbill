#!/bin/bash
clear

# HostBill Platform Installation Script, Enterprise Edition
# Debian 13 (Trixie) + php-8.1
# Rev: 2026-04-27

set -o pipefail

# --- Configuration ---
MIRROR=http://install.hostbillapp.com/installv2/
LOG=/root/hostbillinstall.log
USER="hostbill"
TOTAL_STEPS=10

# --- Package Tracking ---
INSTALLED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0
FAILED_PKGS=""

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ============================================================
# Logging & Output
# ============================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

step() {
    local num=$1; shift
    echo ""
    echo -e " ${BLUE}${BOLD}[$num/$TOTAL_STEPS]${NC} ${BOLD}$*${NC}"
    log "===== STEP $num/$TOTAL_STEPS: $* ====="
}

ok() {
    echo -e "       ${GREEN}✓${NC} $1"
    log "  OK: $1"
}

warn() {
    echo -e "       ${YELLOW}⚠${NC} $1"
    log "  WARN: $1"
}

fail() {
    echo -e "       ${RED}✗${NC} $1"
    log "  FAIL: $1"
}

skip() {
    echo -e "       ${DIM}→ $1 (already installed)${NC}"
    log "  SKIP: $1"
}

die() {
    fail "$1"
    echo ""
    echo -e " ${RED}${BOLD}Installation aborted.${NC} Check log: $LOG"
    exit 1
}

# ============================================================
# Package Management
# ============================================================

pkg_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q '^ii'
}

pkg_available() {
    apt-cache show "$1" > /dev/null 2>&1
}

# Install a single package with existence/availability checks.
# Usage: install_pkg <name> [critical]
#   critical=true  -> abort entire install on failure
#   critical=false -> log failure, continue (default)
install_pkg() {
    local pkg="$1"
    local critical="${2:-false}"

    if pkg_installed "$pkg"; then
        skip "$pkg"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        return 0
    fi

    if ! pkg_available "$pkg"; then
        if [ "$critical" = "true" ]; then
            die "$pkg not found in repositories (critical dependency)"
        fi
        warn "$pkg not found in repositories, skipping"
        FAILED_PKGS="$FAILED_PKGS $pkg"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        return 1
    fi

    if apt-get install -y "$pkg" >> "$LOG" 2>&1; then
        ok "$pkg"
        INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
        return 0
    else
        if [ "$critical" = "true" ]; then
            die "$pkg installation failed (critical dependency)"
        fi
        fail "$pkg installation failed, continuing"
        FAILED_PKGS="$FAILED_PKGS $pkg"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        return 1
    fi
}

# Install a list of packages.
# Usage: install_packages <critical: true|false> pkg1 pkg2 ...
install_packages() {
    local critical="$1"; shift
    for pkg in "$@"; do
        install_pkg "$pkg" "$critical"
    done
}

# Run a helper script with logging.
# Usage: run_script <description> <script_path> [args...]
run_script() {
    local desc="$1"; shift
    local script="$1"; shift

    if [ ! -f "$script" ]; then
        fail "$desc — script not found: $script"
        return 1
    fi

    if /bin/bash "$script" "$@" >> "$LOG" 2>&1; then
        ok "$desc"
        return 0
    else
        fail "$desc"
        return 1
    fi
}

# ============================================================
# OS Validation
# ============================================================

check_os() {
    local id codename arch

    id=$(lsb_release -i 2>/dev/null | cut -f2)
    codename=$(lsb_release -c 2>/dev/null | cut -f2)
    arch=$(uname -m)

    if [ "$id" != 'Debian' ] || [ "$codename" != 'trixie' ]; then
        die "Requires Debian 13 (Trixie). Detected: $id $codename"
    fi
    if [ "$arch" != "x86_64" ]; then
        die "Requires x86_64. Detected: $arch"
    fi
    if [ "$(whoami)" != 'root' ]; then
        die "Please run this script as root"
    fi
    if [ ! -e /usr/bin/apt-get ]; then
        die "apt-get not found"
    fi
    if [ -e /usr/local/cpanel ]; then
        die "cPanel detected — install on a clean Debian system only"
    fi
    if [ -e /usr/local/directadmin ]; then
        die "DirectAdmin detected — install on a clean Debian system only"
    fi

    ok "OS: Debian 13 (Trixie) x86_64"
}

# ============================================================
# License Input
# ============================================================

LICENSE=$1

if [ -z "$LICENSE" ]; then
    echo -n "Please enter your license activation code: "
    read -r LICENSE
    if [ -z "$LICENSE" ]; then
        echo "License code is required for install"
        exit 1
    fi
fi

HST=$2
if [ -z "$HST" ]; then
    HST=$(hostname)
fi

# ============================================================
# Banner
# ============================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e " ${BOLD}HostBill Installer${NC} — Debian 13 (Trixie)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e " ${DIM}Log:      $LOG${NC}"
echo -e " ${DIM}Hostname: $HST${NC}"

echo "==========================================" > "$LOG"
log "HostBill Platform Installation Started"
log "Hostname: $HST"
log "=========================================="

check_os

export DEBIAN_FRONTEND=noninteractive

# ─────────────────────────────────────────────────────────────
step 1 "Installing base dependencies"
# ─────────────────────────────────────────────────────────────

apt-get update -y >> "$LOG" 2>&1 && ok "Package lists updated" \
    || warn "apt-get update had warnings (check log)"

existing_php=$(dpkg --list 2>/dev/null | grep php | awk '/^ii/{ print $2}')
if [ -n "$existing_php" ]; then
    warn "Removing existing PHP packages to avoid conflicts"
    # shellcheck disable=SC2086
    apt-get --purge remove $existing_php -y >> "$LOG" 2>&1 \
        || warn "Some PHP packages could not be removed"
fi

# Add sury.org PHP repository for PHP 8.1
if [ ! -f /etc/apt/sources.list.d/php.list ]; then
    if wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg >> "$LOG" 2>&1 \
       && echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list; then
        ok "sury.org PHP repository added"
        apt-get update -y >> "$LOG" 2>&1 || true
    else
        die "Failed to add sury.org PHP repository (critical)"
    fi
else
    skip "sury.org PHP repository (already configured)"
fi

install_packages true  apt-transport-https lsb-release ca-certificates curl wget gnupg2
install_packages false unzip cron snmp
install_packages true  mariadb-server mariadb-client

# ─────────────────────────────────────────────────────────────
step 2 "Downloading platform installation files"
# ─────────────────────────────────────────────────────────────

mkdir -p /usr/local/hostbill >> "$LOG" 2>&1

cp -rf ./etc /usr/local/hostbill/          >> "$LOG" 2>&1
cp -rf ./installtools /usr/local/hostbill/ >> "$LOG" 2>&1
cp -rf ./scripts /usr/local/hostbill/      >> "$LOG" 2>&1
ok "Platform files copied to /usr/local/hostbill/"

# ─────────────────────────────────────────────────────────────
step 3 "Pre-installation checks"
# ─────────────────────────────────────────────────────────────

# Disable apache2 if present (non-critical)
if systemctl is-active --quiet apache2 2>/dev/null; then
    systemctl disable apache2 >> "$LOG" 2>&1 || true
    systemctl stop apache2    >> "$LOG" 2>&1 || true
    ok "Disabled system apache2"
else
    skip "apache2 (not running)"
fi

# Firewall setup (non-critical)
install_pkg ufw false
if command -v ufw > /dev/null 2>&1; then
    ufw allow http  >> "$LOG" 2>&1 || true
    ufw allow https >> "$LOG" 2>&1 || true
    ufw --force enable >> "$LOG" 2>&1 || true
    ok "Firewall configured (HTTP + HTTPS allowed)"
else
    warn "ufw not available, skipping firewall setup"
fi

# ─────────────────────────────────────────────────────────────
step 4 "Setting up /home/${USER} directory"
# ─────────────────────────────────────────────────────────────

run_script "User and directory setup" /usr/local/hostbill/scripts/8/setup_user.sh "$USER" \
    || die "Failed to set up user directory (critical)"

# ─────────────────────────────────────────────────────────────
step 5 "Installing webserver (nginx)"
# ─────────────────────────────────────────────────────────────

install_pkg nginx true

run_script "nginx defaults"            /usr/local/hostbill/scripts/debian13/nginx_setup_defaults.sh "$HST"
run_script "Self-signed SSL cert"      /usr/local/hostbill/scripts/nginx_self_signedssl.sh "$HST"
run_script "nginx host configuration"  /usr/local/hostbill/scripts/debian13/nginx_add.sh "$USER" 9000 "$HST"

# ─────────────────────────────────────────────────────────────
step 6 "Installing PHP 8.1"
# ─────────────────────────────────────────────────────────────

# Core PHP packages — critical, nginx+fpm will not work without these
install_packages true php8.1 php8.1-fpm php8.1-cli

# NOTE: php8.1-json removed  — JSON is built into PHP 8.0+ core (always available).
# NOTE: php8.1-sodium removed — sodium is compiled into the sury.org PHP 8.1 binary.

# PHP extensions — non-critical, install continues if any individual package fails
install_packages false \
    php8.1-xml \
    php8.1-bcmath \
    php8.1-gd \
    php8.1-imap \
    php8.1-snmp \
    php8.1-soap \
    php8.1-mbstring \
    php8.1-mysql \
    php8.1-ldap \
    php8.1-curl \
    php8.1-memcached

run_script "php-fpm defaults"       /usr/local/hostbill/scripts/debian13/php-fpm_setup_defaults.sh
run_script "php-fpm configuration"  /usr/local/hostbill/scripts/debian13/php-fpm_add.sh "$USER" 9000

# ionCube Loader
echo -e "       ${DIM}Installing ionCube Loader...${NC}"
if (
    cd /root || exit 1
    wget http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.zip \
        -O /root/ioncube.zip >> "$LOG" 2>&1 \
    && unzip -o ioncube.zip >> "$LOG" 2>&1 \
    && cp /root/ioncube/ioncube_loader_lin_8.1.so /usr/lib/php/20210902/ \
    && chmod +x /usr/lib/php/20210902/ioncube_loader_lin_8.1.so \
    && echo "zend_extension=/usr/lib/php/20210902/ioncube_loader_lin_8.1.so" > /etc/php/8.1/mods-available/ioncube.ini \
    && ln -sf /etc/php/8.1/mods-available/ioncube.ini /etc/php/8.1/cli/conf.d/10-ioncube.ini \
    && ln -sf /etc/php/8.1/mods-available/ioncube.ini /etc/php/8.1/fpm/conf.d/10-ioncube.ini
); then
    ok "ionCube Loader"
else
    fail "ionCube Loader installation failed"
fi
/bin/rm -rf /root/ioncube* >> "$LOG" 2>&1 || true

# ─────────────────────────────────────────────────────────────
step 7 "Installing memcached"
# ─────────────────────────────────────────────────────────────

install_pkg memcached false

# ─────────────────────────────────────────────────────────────
step 8 "Installing certbot"
# ─────────────────────────────────────────────────────────────

install_packages false certbot python3-certbot-nginx

run_script "Logrotate configuration" /usr/local/hostbill/scripts/logrotate.sh

# ─────────────────────────────────────────────────────────────
step 9 "Detecting server IP"
# ─────────────────────────────────────────────────────────────

IP=$(wget -qO- http://install.hostbillapp.com/ip.php 2>/dev/null) || true
if [ -n "$IP" ]; then
    ok "Server IP: $IP"
else
    warn "Could not detect external IP — falling back to 127.0.0.1"
    IP="127.0.0.1"
fi

# Disable SQL strict mode
echo ''          >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo '[mysqld]'  >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo 'sql_mode=' >> /etc/mysql/mariadb.conf.d/50-server.cnf
ok "MariaDB strict mode disabled"

# ─────────────────────────────────────────────────────────────
step 10 "Enabling & restarting services"
# ─────────────────────────────────────────────────────────────

for svc in mariadb nginx php8.1-fpm memcached; do
    if systemctl enable "$svc" >> "$LOG" 2>&1; then
        if systemctl restart "$svc" >> "$LOG" 2>&1; then
            ok "Service: $svc"
        else
            fail "Service $svc — failed to restart"
        fi
    else
        warn "Service $svc — could not be enabled (not installed?)"
    fi
done

# ============================================================
# Summary
# ============================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e " ${BOLD}Installation Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${GREEN}Installed${NC}:  $INSTALLED_COUNT packages"
echo -e "  ${DIM}Skipped${NC}:    $SKIPPED_COUNT packages (already present)"
if [ "$FAILED_COUNT" -gt 0 ]; then
    echo -e "  ${RED}Failed${NC}:     $FAILED_COUNT packages"
    echo -e "  ${RED}└─${NC}${FAILED_PKGS}"
else
    echo -e "  ${GREEN}Failed${NC}:     0"
fi
echo ""
echo -e "  ${DIM}Full log: $LOG${NC}"
echo ""

if [ "$FAILED_COUNT" -gt 0 ]; then
    echo -e " ${YELLOW}⚠ Completed with warnings — review failed packages above.${NC}"
else
    echo -e " ${GREEN}✓ All packages installed successfully.${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e " ${BOLD}Installing HostBill application${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

/usr/bin/php /usr/local/hostbill/installtools/main.php -l "$LICENSE" -i "$IP" -c memcached -h "$HST"
