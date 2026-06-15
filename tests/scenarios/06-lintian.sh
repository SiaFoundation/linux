#!/usr/bin/env bash
# lintian check.
# only run it on trixie because older lintian lacks needed tags and flags.
# shellcheck source=tests/scenarios/helpers.sh
. /work/tests/scenarios/helpers.sh

. /etc/os-release
if [ "${VERSION_CODENAME:-}" != trixie ]; then
    echo "skipping lintian, only runs on debian trixie"
    exit 0
fi

apt-get update > /dev/null
DEBIAN_FRONTEND=noninteractive apt-get install -y lintian > /dev/null

# build the suppression tag list from the file.
tags=$(grep -vE '^(#|$)' /work/tests/lintian-suppressions.txt | paste -sd,)

lintian --fail-on error,warning ${tags:+--suppress-tags "$tags"} "$(deb 1.0.0)"
