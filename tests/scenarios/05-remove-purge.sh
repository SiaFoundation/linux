#!/usr/bin/env bash
# remove leaves admin config and data; purge deletes all of it.
# shellcheck source=tests/scenarios/helpers.sh
. /work/tests/scenarios/helpers.sh

install_deb "$(deb 1.0.0)"
# create admin config and data the package never shipped.
mkdir -p "/etc/$PKG"
printf 'directory: /var/lib/%s\n# local change\n' "$PKG" > "/etc/$PKG/$PKG.yml"
echo "wallet data" > "/var/lib/$PKG/keep.dat"
systemctl enable --now "$PKG.service"
sleep 1

DEBIAN_FRONTEND=noninteractive apt-get remove -y "$PKG" > /dev/null

# remove deletes package files but keeps config and data.
assert_no_path "/usr/bin/$PKG"
assert_no_path "/usr/lib/systemd/system/$PKG.service"
[ "$(active_state)" != active ] || fail "service still running after remove"
assert_file "/etc/$PKG/$PKG.yml"
assert_file "/var/lib/$PKG/keep.dat"

# reinstall after remove keeps config and stays disabled.
install_deb "$(deb 1.0.0)"
assert_eq "$(unit_state)" disabled "reinstall must not auto enable"
grep -q '# local change' "/etc/$PKG/$PKG.yml" || fail "config lost across remove and reinstall"

DEBIAN_FRONTEND=noninteractive apt-get purge -y "$PKG" > /dev/null

# purge deletes everything.
assert_no_path "/etc/$PKG"
assert_no_path "/var/lib/$PKG"
