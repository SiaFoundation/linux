#!/usr/bin/env bash
# admin config and systemd drop-ins survive upgrades byte for byte.
# the package ships no config, so dpkg should not touch them.
# shellcheck source=tests/scenarios/helpers.sh
. /work/tests/scenarios/helpers.sh

install_deb "$(deb 1.0.0)"

# fake what "$PKG config" and "systemctl edit" would create.
mkdir -p "/etc/$PKG"
printf 'directory: /var/lib/%s\n# local change\n' "$PKG" > "/etc/$PKG/$PKG.yml"
mkdir -p "/etc/systemd/system/$PKG.service.d"
printf '[Service]\nEnvironment=SIA_TEST_OVERRIDE=1\n' > "/etc/systemd/system/$PKG.service.d/override.conf"
systemctl daemon-reload

sum_config=$(sha256sum "/etc/$PKG/$PKG.yml" | cut -d' ' -f1)
sum_dropin=$(sha256sum "/etc/systemd/system/$PKG.service.d/override.conf" | cut -d' ' -f1)

systemctl enable --now "$PKG.service"
sleep 1

install_deb "$(deb 2.0.0)"
sleep 1

assert_eq "$(sha256sum "/etc/$PKG/$PKG.yml" | cut -d' ' -f1)" "$sum_config" "admin config changed during upgrade"
assert_eq "$(sha256sum "/etc/systemd/system/$PKG.service.d/override.conf" | cut -d' ' -f1)" "$sum_dropin" "drop-in changed during upgrade"
systemctl show "$PKG.service" -p Environment | grep -q SIA_TEST_OVERRIDE || fail "drop-in no longer effective after upgrade"
assert_eq "$(active_state)" active
