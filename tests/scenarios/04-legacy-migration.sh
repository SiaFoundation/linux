#!/usr/bin/env bash
# migration from old packages.
# they put the unit in /etc/systemd/system and had an unsafe prerm.
# shellcheck source=tests/scenarios/helpers.sh
. /work/tests/scenarios/helpers.sh

# case a: stock old unit, configured and enabled.
# new vendor unit takes over and the service comes back.
install_deb "$(deb 0.9.1)"
assert_file "/etc/systemd/system/$PKG.service"
write_config
legacy_enable_now
sleep 1

install_deb "$(deb 1.0.0)"
sleep 1
assert_no_path "/etc/systemd/system/$PKG.service"
assert_no_path "/etc/systemd/system/$PKG.service.dpkg-bak"
assert_vendor_unit_active
assert_eq "$(unit_state)" enabled "migration must re enable a configured install"
assert_eq "$(active_state)" active "migration must restart a configured install"
cleanup_package

# case a2: older stock unit, before TimeoutStopSec existed.
install_deb "$(deb 0.9.0)"
write_config
legacy_enable_now
install_deb "$(deb 1.0.0)"
sleep 1
assert_no_path "/etc/systemd/system/$PKG.service"
assert_vendor_unit_active
assert_eq "$(active_state)" active
cleanup_package

# case a3: changed Description still counts as stock.
# the old workflow got it from free text.
install_deb "$(deb 0.9.1)"
sed -i 's/^Description=.*/Description=my own description/' "/etc/systemd/system/$PKG.service"
systemctl daemon-reload
write_config
legacy_enable_now
install_deb "$(deb 1.0.0)"
sleep 1
assert_no_path "/etc/systemd/system/$PKG.service"
assert_vendor_unit_active
cleanup_package

# case b: real unit change.
# keep it in /etc so it overrides the vendor unit.
install_deb "$(deb 0.9.1)"
sed -i 's/^RestartSec=15$/RestartSec=30/' "/etc/systemd/system/$PKG.service"
systemctl daemon-reload
write_config
legacy_enable_now
sleep 1

install_deb "$(deb 1.0.0)"
sleep 1
assert_file "/etc/systemd/system/$PKG.service"
grep -q '^RestartSec=30$' "/etc/systemd/system/$PKG.service" || fail "modified unit content lost"
assert_no_path "/etc/systemd/system/$PKG.service.dpkg-bak"
assert_eq "$(fragment_path)" "/etc/systemd/system/$PKG.service" "preserved unit must override the vendor unit"
assert_eq "$(unit_state)" enabled
assert_eq "$(active_state)" active

# case d: next upgrade is normal.
# do not run migration again or change enablement, even with a unit in /etc.
systemctl disable --now "$PKG.service"
install_deb "$(deb 2.0.0)"
assert_no_path "/run/sia-linux/$PKG.legacy-upgrade"
assert_file "/etc/systemd/system/$PKG.service"
grep -q '^RestartSec=30$' "/etc/systemd/system/$PKG.service" || fail "preserved unit touched by regular upgrade"
assert_no_path "/etc/systemd/system/$PKG.service.dpkg-bak"
assert_eq "$(unit_state)" disabled "regular upgrade must not re enable"
assert_eq "$(active_state)" inactive
cleanup_package
rm -f "/etc/systemd/system/$PKG.service"
systemctl daemon-reload

# case c: old install with no config stays off after migration.
install_deb "$(deb 0.9.1)"
install_deb "$(deb 1.0.0)"
assert_file "/usr/lib/systemd/system/$PKG.service"
assert_eq "$(unit_state)" disabled "unconfigured migration must not enable"
assert_eq "$(active_state)" inactive
