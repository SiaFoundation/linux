#!/usr/bin/env bash
# builds a fake old .deb for migration tests.
# it keeps the old quirks: unit in /etc, unsafe prerm, no conffiles, no md5sums.
# the unit text matches the old script byte for byte.
# shellcheck disable=SC2129
set -euo pipefail

usage() {
    echo "usage: $0 --project <name> --version <version> --arch <amd64|arm64> --binary <path> --variant <a|b> --output <dir>" >&2
    exit 1
}

PROJECT='' VERSION='' ARCH='' BINARY='' VARIANT='' OUTPUT=''
while [ $# -gt 0 ]; do
    case "$1" in
    --project) PROJECT=$2; shift 2 ;;
    --version) VERSION=$2; shift 2 ;;
    --arch) ARCH=$2; shift 2 ;;
    --binary) BINARY=$2; shift 2 ;;
    --variant) VARIANT=$2; shift 2 ;;
    --output) OUTPUT=$2; shift 2 ;;
    *) usage ;;
    esac
done
if [ -z "$PROJECT" ] || [ -z "$VERSION" ] || [ -z "$ARCH" ] || [ -z "$BINARY" ] || [ -z "$VARIANT" ] || [ -z "$OUTPUT" ]; then
    usage
fi

ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=/dev/null
. "$ROOT/packages/$PROJECT/package.env"
DESCRIPTION=$PKG_DESCRIPTION
# shellcheck source=scripts/legacy-unit.sh
. "$ROOT/scripts/legacy-unit.sh"

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
chmod 755 "$STAGE"

mkdir -p "$STAGE/DEBIAN"
mkdir -p "$STAGE/usr/bin"
mkdir -p "$STAGE/var/lib/$PROJECT"
mkdir -p "$STAGE/etc/systemd/system"

cp "$BINARY" "$STAGE/usr/bin/$PROJECT"
chmod 755 "$STAGE/usr/bin/$PROJECT"

# control file, mirrors the historical echo block line by line on purpose
# shellcheck disable=SC2129
echo "Package: $PROJECT" > "$STAGE/DEBIAN/control"
echo "Version: $VERSION" >> "$STAGE/DEBIAN/control"
echo "Architecture: $ARCH" >> "$STAGE/DEBIAN/control"
echo "Maintainer: The Sia Foundation <hello@sia.tech>" >> "$STAGE/DEBIAN/control"
echo "Priority: optional" >> "$STAGE/DEBIAN/control"
echo "Section: net" >> "$STAGE/DEBIAN/control"
echo "Description: $DESCRIPTION" >> "$STAGE/DEBIAN/control"
echo "Homepage: https://github.com/SiaFoundation/$PROJECT" >> "$STAGE/DEBIAN/control"

# use the shared old unit text so the test package and hash stay in sync.
UNIT=$STAGE/etc/systemd/system/$PROJECT.service
legacy_unit "$PROJECT" "$DESCRIPTION" "$VARIANT" > "$UNIT"

# same unsafe prerm the old packages had.
echo "#!/bin/sh" > "$STAGE/DEBIAN/prerm"
echo "systemctl stop $PROJECT.service" >> "$STAGE/DEBIAN/prerm"
echo "systemctl disable $PROJECT.service" >> "$STAGE/DEBIAN/prerm"
chmod +x "$STAGE/DEBIAN/prerm"

mkdir -p "$OUTPUT"
dpkg-deb --root-owner-group -Zxz --build "$STAGE" "$OUTPUT/${PROJECT}_${VERSION}_${ARCH}.deb" > /dev/null
echo "built $OUTPUT/${PROJECT}_${VERSION}_${ARCH}.deb"
