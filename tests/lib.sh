#!/usr/bin/env bash
# container helpers for the package tests, loaded by run-tests.sh

start_container() {
    local cgroup_args=(--cgroupns=host -v /sys/fs/cgroup:/sys/fs/cgroup:rw)
    if [ "${CGROUP_MODE:-}" = private ]; then
        cgroup_args=(--cgroupns=private)
    fi

    docker run -d --rm \
        --privileged \
        "${cgroup_args[@]}" \
        --tmpfs /run \
        --tmpfs /tmp \
        -v "$ROOT":/src:ro \
        "$TEST_IMAGE" /sbin/init
}

wait_for_systemd() {
    local cid=$1
    local state
    for _ in $(seq 1 90); do
        state=$(docker exec "$cid" systemctl is-system-running 2>/dev/null || true)
        case "$state" in
        running|degraded) return 0 ;;
        esac
        sleep 1
    done
    echo "systemd did not become ready in container $cid, last state: ${state:-unknown}" >&2
    echo "try CGROUP_MODE=private if this persists" >&2
    return 1
}

stop_container() {
    local cid=$1
    docker rm -f "$cid" > /dev/null 2>&1 || true
}
