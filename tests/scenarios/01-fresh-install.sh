#!/usr/bin/env bash
# fresh install: correct layout, no shipped config or conffiles, service stays
# off until the admin enables it.
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

# the package ships no config and no logrotate rule; the daemon writes its config.
assert_no_path "/etc/$PKG/$PKG.yml"
assert_no_path "/etc/logrotate.d/$PKG"

# dpkg registers no conffiles.
conffiles=$(dpkg-query -W -f='${Conffiles}' "$PKG" | tr -d '[:space:]')
[ -z "$conffiles" ] || fail "package should register no conffiles, got: $conffiles"

# a pristine install verifies cleanly.
dpkg -V "$PKG" || fail "dpkg -V reported differences on a pristine install"

# service stays off by default.
assert_eq "$(unit_state)" disabled "fresh install enablement"
assert_eq "$(active_state)" inactive "fresh install activity"

# manual enable/start works.
systemctl enable --now "$PKG.service"
sleep 1
assert_eq "$(unit_state)" enabled
assert_eq "$(active_state)" active
