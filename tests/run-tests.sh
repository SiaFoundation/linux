#!/usr/bin/env bash
# package test runner.
# builds the stub daemon, boots one systemd container per scenario,
# builds the debs inside it, then runs the scenario checks.
#
# usage: tests/run-tests.sh [--image debian:bookworm] [--project hostd]
#                           [--scenario <substring>] [--keep]
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=tests/lib.sh
. "$ROOT/tests/lib.sh"

IMAGE=debian:bookworm
PROJECT=hostd
FILTER=''
KEEP=0
while [ $# -gt 0 ]; do
    case "$1" in
    --image) IMAGE=$2; shift 2 ;;
    --project) PROJECT=$2; shift 2 ;;
    --scenario) FILTER=$2; shift 2 ;;
    --keep) KEEP=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
    esac
done

case "$(uname -m)" in
x86_64) ARCH=amd64 ;;
arm64|aarch64) ARCH=arm64 ;;
*) echo "unsupported host architecture: $(uname -m)" >&2; exit 1 ;;
esac

echo "== building stub daemon for linux/$ARCH"
mkdir -p "$ROOT/dist"
# stripped like the release binaries so lintian sees the same shape
(cd "$ROOT/tests/stub" && CGO_ENABLED=0 GOOS=linux GOARCH=$ARCH go build -trimpath -ldflags '-s -w' -o "$ROOT/dist/stub-linux-$ARCH" .)

TEST_IMAGE=sia-linux-test:$(echo "$IMAGE" | tr ':/' '--')
echo "== building test image $TEST_IMAGE from $IMAGE"
docker build -q -t "$TEST_IMAGE" --build-arg "BASE_IMAGE=$IMAGE" -f "$ROOT/tests/Dockerfile.systemd" "$ROOT/tests" > /dev/null

declare -a failed=()
ran=0
for scenario in "$ROOT"/tests/scenarios/[0-9]*.sh; do
    name=$(basename "$scenario")
    if [ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]]; then
        continue
    fi
    ran=$((ran + 1))

    echo "== $name ($IMAGE, $PROJECT, $ARCH)"
    cid=$(start_container)
    if ! wait_for_systemd "$cid"; then
        stop_container "$cid"
        failed+=("$name (systemd not ready)")
        continue
    fi

    if docker exec "$cid" bash /src/tests/container-prep.sh "$PROJECT" "$ARCH" \
        && docker exec -e "PKG=$PROJECT" -e "ARCH=$ARCH" "$cid" bash "/work/tests/scenarios/$name"; then
        echo "== PASS $name"
    else
        echo "== FAIL $name" >&2
        failed+=("$name")
        if [ "$KEEP" = 1 ]; then
            echo "== container kept for debugging: $cid" >&2
            continue
        fi
    fi
    stop_container "$cid"
done

if [ "$ran" -eq 0 ]; then
    echo "no scenario matched filter '$FILTER'" >&2
    exit 1
fi
if [ "${#failed[@]}" -gt 0 ]; then
    echo "failed scenarios: ${failed[*]}" >&2
    exit 1
fi
echo "all $ran scenarios passed"
