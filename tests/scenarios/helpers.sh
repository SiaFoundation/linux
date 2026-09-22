#!/usr/bin/env bash
# helpers loaded by every scenario.
# they run as root in the test container with PKG and ARCH set.
set -euo pipefail

: "${PKG:?PKG must be set}"
: "${ARCH:?ARCH must be set}"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

deb() {
    echo "/work/dist/${PKG}_$1_${ARCH}.deb"
}

install_deb() {
    local out
    out=$(DEBIAN_FRONTEND=noninteractive apt-get install -y "$1" 2>&1) \
        || { echo "$out" >&2; fail "failed to install $1"; }
}

assert_file() {
    [ -f "$1" ] || fail "expected file $1"
}

assert_dir() {
    [ -d "$1" ] || fail "expected directory $1"
}

assert_no_path() {
    [ ! -e "$1" ] || fail "expected $1 to be absent"
}

assert_eq() {
    [ "$1" = "$2" ] || fail "${3:-values differ}: got '$1', want '$2'"
}

unit_state() {
    systemctl is-enabled "$PKG.service" 2>/dev/null || true
}

active_state() {
    systemctl is-active "$PKG.service" 2>/dev/null || true
}

main_pid() {
    systemctl show -p MainPID --value "$PKG.service"
}

fragment_path() {
    systemctl show -p FragmentPath --value "$PKG.service"
}

# merged usr can show the vendor unit under /lib or /usr/lib.
assert_vendor_unit_active() {
    case "$(fragment_path)" in
    "/usr/lib/systemd/system/$PKG.service"|"/lib/systemd/system/$PKG.service") ;;
    *) fail "vendor unit must be the active fragment, got '$(fragment_path)'" ;;
    esac
}

write_config() {
    mkdir -p "/var/lib/$PKG"
    echo "# test config" > "/var/lib/$PKG/$PKG.yml"
}

# systemd before 252 cannot enable the old alias.
# do what admins did: create the wants link and start it.
legacy_enable_now() {
    if ! systemctl enable --now "$PKG.service" 2>/dev/null; then
        mkdir -p "/etc/systemd/system/multi-user.target.wants"
        ln -sf "/etc/systemd/system/$PKG.service" "/etc/systemd/system/multi-user.target.wants/$PKG.service"
        systemctl daemon-reload
        systemctl start "$PKG.service"
    fi
}

# reset package state between subcases.
cleanup_package() {
    DEBIAN_FRONTEND=noninteractive apt-get purge -y "$PKG" > /dev/null 2>&1 || true
    rm -rf "/var/lib/$PKG" "/run/sia-linux"
    systemctl daemon-reload
}
