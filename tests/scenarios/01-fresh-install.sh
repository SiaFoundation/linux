#!/usr/bin/env bash
# fresh install: files land in the right places, the package ships no config
# or conffiles, the service stays disabled until the admin opts in
# shellcheck source=tests/scenarios/helpers.sh
. /work/tests/scenarios/helpers.sh

install_deb "$(deb 1.0.0)"

# layout
[ -x "/usr/bin/$PKG" ] || fail "binary missing or not executable"
assert_file "/usr/lib/systemd/system/$PKG.service"
assert_no_path "/etc/systemd/system/$PKG.service"
assert_dir "/var/lib/$PKG"
assert_file "/usr/share/doc/$PKG/copyright"
assert_file "/usr/share/doc/$PKG/changelog.gz"

# config is made by "$PKG config", not shipped in the package.
assert_no_path "/etc/$PKG/$PKG.yml"
assert_no_path "/etc/logrotate.d/$PKG"

# no dpkg-managed config files.
conffiles=$(dpkg-query -W -f='${Conffiles}' "$PKG" | tr -d '[:space:]')
[ -z "$conffiles" ] || fail "package should register no conffiles, got: $conffiles"

# pristine install should verify cleanly.
dpkg -V "$PKG" || fail "dpkg -V reported differences on a pristine install"

# service stays off by default.
assert_eq "$(unit_state)" disabled "fresh install enablement"
assert_eq "$(active_state)" inactive "fresh install activity"

# manual enable/start works.
systemctl enable --now "$PKG.service"
sleep 1
assert_eq "$(unit_state)" enabled
assert_eq "$(active_state)" active
