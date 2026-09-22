#!/usr/bin/env bash
# builds a .deb for one Sia daemon from a linux binary that is already built.
# package settings come from packages/<project>/package.env.
# the workflow uses this, so a local build produces the same package.
set -euo pipefail

usage() {
    echo "usage: $0 --project <name> --version <version> --arch <amd64|arm64> --binary <path> --output <dir>" >&2
    exit 1
}

PROJECT='' VERSION='' ARCH='' BINARY='' OUTPUT=''
while [ $# -gt 0 ]; do
    case "$1" in
    --project) PROJECT=$2; shift 2 ;;
    --version) VERSION=$2; shift 2 ;;
    --arch) ARCH=$2; shift 2 ;;
    --binary) BINARY=$2; shift 2 ;;
    --output) OUTPUT=$2; shift 2 ;;
    *) usage ;;
    esac
done
if [ -z "$PROJECT" ] || [ -z "$VERSION" ] || [ -z "$ARCH" ] || [ -z "$BINARY" ] || [ -z "$OUTPUT" ]; then
    usage
fi

case "$ARCH" in
amd64|arm64) ;;
*) echo "unsupported architecture: $ARCH" >&2; exit 1 ;;
esac
[ -f "$BINARY" ] || { echo "binary not found: $BINARY" >&2; exit 1; }

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PKG_DIR=$ROOT/packages/$PROJECT
TEMPLATES=$ROOT/scripts/templates

[ -f "$PKG_DIR/package.env" ] || { echo "missing $PKG_DIR/package.env, add a package definition first" >&2; exit 1; }
# shellcheck source=/dev/null
. "$PKG_DIR/package.env"
# the binary, unit, and data dir use the project name.
# the apt name defaults to it unless package.env overrides it.
PKG_NAME=$PROJECT
: "${PKG_DEBIAN_NAME:=$PKG_NAME}"
# a package that installs a path another distro package owns must declare it,
# or dpkg refuses the unpack.
PKG_CONFLICTS=${PKG_CONFLICTS:+Conflicts: $PKG_CONFLICTS}
# the leading space belongs to the value so a project without extra arguments
# does not get a trailing space on its ExecStart line.
PKG_EXEC_ARGS=${PKG_EXEC_ARGS:+ $PKG_EXEC_ARGS}

# quote replacements so bash treats &, backslashes, and other chars as plain text.
render() {
    local content
    content=$(cat "$1")
    content=${content//@PKG_NAME@/"$PKG_NAME"}
    content=${content//@PKG_DEBIAN_NAME@/"$PKG_DEBIAN_NAME"}
    content=${content//@PKG_VERSION@/"$VERSION"}
    content=${content//@PKG_ARCH@/"$ARCH"}
    content=${content//@PKG_DESCRIPTION@/"$PKG_DESCRIPTION"}
    content=${content//@PKG_LONG_DESCRIPTION@/"$PKG_LONG_DESCRIPTION"}
    content=${content//@PKG_HOMEPAGE@/"$PKG_HOMEPAGE"}
    content=${content//@PKG_CONFLICTS@/"$PKG_CONFLICTS"}
    content=${content//@PKG_EXEC_ARGS@/"$PKG_EXEC_ARGS"}
    content=${content//@PKG_INSTALLED_SIZE@/"${PKG_INSTALLED_SIZE:-0}"}
    printf '%s\n' "$content"
}

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
chmod 755 "$STAGE"

# payload
install -Dm755 "$BINARY" "$STAGE/usr/bin/$PKG_NAME"

install -dm755 "$STAGE/usr/lib/systemd/system"
render "$TEMPLATES/service.tmpl" > "$STAGE/usr/lib/systemd/system/$PKG_NAME.service"
chmod 644 "$STAGE/usr/lib/systemd/system/$PKG_NAME.service"

# the daemon owns config via "<name> config".
# the package ships no config, so dpkg never overwrites it.
# the directories are shipped empty so the daemon user can write to them.
install -dm700 "$STAGE/etc/$PKG_NAME"
install -dm700 "$STAGE/var/lib/$PKG_NAME"

install -dm755 "$STAGE/usr/share/doc/$PKG_DEBIAN_NAME"
render "$TEMPLATES/copyright.tmpl" > "$STAGE/usr/share/doc/$PKG_DEBIAN_NAME/copyright"
chmod 644 "$STAGE/usr/share/doc/$PKG_DEBIAN_NAME/copyright"
# dpkg treats a version containing a dash as non native, which must name its
# changelog changelog.Debian.gz. Versions without one use changelog.gz.
case "$VERSION" in
*-*) CHANGELOG=changelog.Debian.gz ;;
*)   CHANGELOG=changelog.gz ;;
esac
# honor SOURCE_DATE_EPOCH so identical inputs produce a byte identical package
CHANGELOG_DATE=$(date -R -u -d "@${SOURCE_DATE_EPOCH:-$(date +%s)}")
{
    printf '%s (%s) stable; urgency=medium\n\n' "$PKG_DEBIAN_NAME" "$VERSION"
    printf '  * Packaged upstream release %s.\n\n' "$VERSION"
    printf ' -- The Sia Foundation <hello@sia.tech>  %s\n' "$CHANGELOG_DATE"
} | gzip -9n > "$STAGE/usr/share/doc/$PKG_DEBIAN_NAME/$CHANGELOG"
chmod 644 "$STAGE/usr/share/doc/$PKG_DEBIAN_NAME/$CHANGELOG"

# control
PKG_INSTALLED_SIZE=$(du -sk "$STAGE" | cut -f1)
install -dm755 "$STAGE/DEBIAN"
render "$TEMPLATES/control.tmpl" | grep -v '^$' > "$STAGE/DEBIAN/control"
for script in postinst prerm postrm; do
    render "$TEMPLATES/$script.tmpl" > "$STAGE/DEBIAN/$script"
    chmod 755 "$STAGE/DEBIAN/$script"
done
(cd "$STAGE" && find . -type f -not -path './DEBIAN/*' | LC_ALL=C sort | sed 's|^\./||' | xargs md5sum > DEBIAN/md5sums)
chmod 644 "$STAGE/DEBIAN/md5sums" "$STAGE/DEBIAN/control"

# force xz so debian and ubuntu get identical packages.
# bookworm defaults to xz and jammy to zstd.
mkdir -p "$OUTPUT"
dpkg-deb --root-owner-group -Zxz --build "$STAGE" "$OUTPUT/${PKG_DEBIAN_NAME}_${VERSION}_${ARCH}.deb" > /dev/null
echo "built $OUTPUT/${PKG_DEBIAN_NAME}_${VERSION}_${ARCH}.deb"
