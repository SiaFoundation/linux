#!/usr/bin/env bash
# runs inside the test container.
# copies the read-only repo to /work and builds the .debs used by scenarios.
set -euo pipefail

PKG=$1
ARCH=$2

mkdir -p /work
cp -r /src/scripts /src/packages /src/tests /work/
cp "/src/dist/stub-linux-$ARCH" /work/stub

for v in 1.0.0 2.0.0 3.0.0; do
    /work/scripts/build-deb.sh --project "$PKG" --version "$v" --arch "$ARCH" --binary /work/stub --output /work/dist
done

/work/tests/build-legacy-deb.sh --project "$PKG" --version 0.9.0 --arch "$ARCH" --binary /work/stub --variant a --output /work/dist
/work/tests/build-legacy-deb.sh --project "$PKG" --version 0.9.1 --arch "$ARCH" --binary /work/stub --variant b --output /work/dist
