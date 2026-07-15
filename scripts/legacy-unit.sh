# shellcheck shell=bash
# one copy of the old systemd unit.
# build-deb.sh hashes it for migrations.
# tests/build-legacy-deb.sh writes it into the fake old package.
# keeping one copy means the hash and test package cannot disagree.
#
# empty desc means no Description line.
# preinst ignores Description because the old workflow got it from free text.
# variant a is older; variant b adds TimeoutStopSec.
legacy_unit() {
    local name=$1 desc=$2 variant=$3
    printf '%s\n' '[Unit]'
    [ -n "$desc" ] && printf 'Description=%s\n' "$desc"
    printf '%s\n' \
        '' \
        'After=network.target' \
        '[Service]' \
        "ExecStart=/usr/bin/$name" \
        "WorkingDirectory=/var/lib/$name" \
        'Restart=always' \
        'RestartSec=15'
    [ "$variant" = b ] && printf 'TimeoutStopSec=120\n'
    printf '%s\n' \
        '' \
        '[Install]' \
        'WantedBy=multi-user.target' \
        "Alias=$name.service"
}
