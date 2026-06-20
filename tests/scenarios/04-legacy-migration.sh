#!/usr/bin/env bash
# migration from the old packages, which shipped the unit in
# /etc/systemd/system and had an unsafe prerm.
# shellcheck source=tests/scenarios/helpers.sh
. /work/tests/scenarios/helpers.sh

# stock unit, configured and enabled: the vendor unit takes over and the
# service comes back.
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
assert_eq "$(unit_state)" enabled "migration must enable a configured install"
assert_eq "$(active_state)" active "migration must restart a configured install"
cleanup_package

# older stock unit, from before TimeoutStopSec was added.
install_deb "$(deb 0.9.0)"
write_config
legacy_enable_now
install_deb "$(deb 1.0.0)"
sleep 1
assert_no_path "/etc/systemd/system/$PKG.service"
assert_vendor_unit_active
assert_eq "$(active_state)" active
cleanup_package

# a description-only edit still counts as stock; the old workflow set it from
# free text.
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

# a real unit edit is kept in /etc and overrides the vendor unit.
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

# a later normal upgrade does not migrate again or change enablement, even with
# a unit still in /etc.
systemctl disable --now "$PKG.service"
install_deb "$(deb 2.0.0)"
assert_no_path "/run/sia-linux/$PKG.legacy-upgrade"
assert_file "/etc/systemd/system/$PKG.service"
grep -q '^RestartSec=30$' "/etc/systemd/system/$PKG.service" || fail "preserved unit touched by regular upgrade"
assert_no_path "/etc/systemd/system/$PKG.service.dpkg-bak"
assert_eq "$(unit_state)" disabled "regular upgrade must not enable"
assert_eq "$(active_state)" inactive
cleanup_package
rm -f "/etc/systemd/system/$PKG.service"
systemctl daemon-reload

# an unconfigured old install stays off after migration.
install_deb "$(deb 0.9.1)"
install_deb "$(deb 1.0.0)"
assert_file "/usr/lib/systemd/system/$PKG.service"
assert_eq "$(unit_state)" disabled "unconfigured migration must not enable"
assert_eq "$(active_state)" inactive
