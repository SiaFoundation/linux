#!/usr/bin/env bash
# upgrade restarts a running service but keeps its enabled/disabled state.
# shellcheck source=tests/scenarios/helpers.sh
. /work/tests/scenarios/helpers.sh

install_deb "$(deb 1.0.0)"
systemctl enable --now "$PKG.service"
sleep 1
pid_before=$(main_pid)

install_deb "$(deb 2.0.0)"
sleep 1
assert_eq "$(active_state)" active "service must be running after upgrade"
pid_after=$(main_pid)
[ "$pid_before" != "$pid_after" ] || fail "service was not restarted on upgrade"
assert_eq "$(unit_state)" enabled "upgrade must keep the service enabled"

# disabled service stays disabled and stopped.
systemctl disable --now "$PKG.service"
install_deb "$(deb 3.0.0)"
assert_eq "$(unit_state)" disabled "upgrade must not enable a disabled service"
assert_eq "$(active_state)" inactive "upgrade must not start a stopped service"
