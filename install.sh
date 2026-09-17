#!/bin/sh
# Installs a Sia package from the official apt repository.
#
#   curl -fsSL https://linux.sia.tech/install.sh | sh
#   curl -fsSL https://linux.sia.tech/install.sh | sh -s -- renterd
set -eu

# everything lives in main so a truncated download runs nothing.
main() {
    REPO_URL=https://linux.sia.tech
    KEYRING=/etc/apt/keyrings/siafoundation.asc
    SOURCES=/etc/apt/sources.list.d/siafoundation.list
    PACKAGE=${1:-hostd}

    # an unknown name would otherwise reach apt, where `s3d` is an unrelated
    # debian package that owns /usr/bin/s3d.
    case "$PACKAGE" in
    hostd | renterd | walletd) ;;
    *) die "unknown package '$PACKAGE', choose hostd, renterd or walletd" ;;
    esac

    command -v apt-get > /dev/null 2>&1 || die "apt-get not found, this installer only supports Debian and Ubuntu"
    SUDO=
    [ "$(id -u)" -eq 0 ] || SUDO=sudo

    detect_suite

    # leave nothing behind if anything below fails. a half written keyring or a
    # sources line pointing at an unverifiable repo breaks every later
    # apt-get update on the machine.
    trap 'rm -f "$SOURCES" "$KEYRING"' EXIT

    echo "installing $PACKAGE for $DISTRO $SUITE"

    # fetch before writing, so a failed download cannot leave an empty keyring.
    # apt reads the armored key directly, no gnupg needed.
    key=$(fetch "$REPO_URL/$DISTRO/gpg")
    printf '%s\n' "$key" | $SUDO install -D -m 644 /dev/stdin "$KEYRING"
    echo "deb [signed-by=$KEYRING] $REPO_URL/$DISTRO $SUITE main" | $SUDO tee "$SOURCES" > /dev/null

    $SUDO apt-get update
    # --no-remove so apt reports a conflict instead of silently uninstalling.
    $SUDO apt-get install -y --no-remove "$PACKAGE"

    trap - EXIT
    echo
    echo "$PACKAGE is installed. The service is not enabled yet."
    echo
    echo "  sudo $PACKAGE config"
    echo "  sudo systemctl enable --now $PACKAGE"
}

die() {
    echo "error: $*" >&2
    exit 1
}

fetch() {
    if command -v curl > /dev/null 2>&1; then
        curl -fsSL "$1"
    elif command -v wget > /dev/null 2>&1; then
        wget -qO- "$1"
    else
        die "need curl or wget to download the signing key"
    fi
}

# sets DISTRO and SUITE to a suite the repository publishes, falling back to the
# newest one when the release is not published yet.
detect_suite() {
    [ -r /etc/os-release ] || die "cannot read /etc/os-release"
    # shellcheck source=/dev/null
    . /etc/os-release

    # derivatives name their base in ID_LIKE and carry their own codename.
    case " ${ID:-} ${ID_LIKE:-} " in
    *" ubuntu "*) DISTRO=ubuntu; SUITE=${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}; NEWEST=questing ;;
    *" debian "*) DISTRO=debian; SUITE=${VERSION_CODENAME:-}; NEWEST=trixie ;;
    *) die "unsupported distribution '${ID:-unknown}', the repository serves Debian and Ubuntu" ;;
    esac
    [ -n "$SUITE" ] || die "could not determine the release codename from /etc/os-release"

    case "$DISTRO/$SUITE" in
    debian/bullseye | debian/bookworm | debian/trixie) ;;
    ubuntu/jammy | ubuntu/noble | ubuntu/questing) ;;
    *)
        echo "no $DISTRO $SUITE suite yet, using $NEWEST, the packages are the same" >&2
        SUITE=$NEWEST
        ;;
    esac
}

main "$@"
