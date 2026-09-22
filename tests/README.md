# Packaging tests

The suite verifies the .deb packages end to end: install layout, config
preservation, upgrades, migration from the legacy packages, removal, and
lintian cleanliness. Each scenario runs inside a fresh systemd enabled
container, and the packages under test are built inside the container by the
same `scripts/build-deb.sh` that builds release packages, only the daemon
binary is replaced with a stub.

## Requirements

Docker and Go. The host architecture decides the package architecture, so
Apple Silicon machines test the arm64 packages against arm64 images.

## Running

```bash
# full suite against one distro
tests/run-tests.sh --image debian:bookworm

# a single scenario while iterating
tests/run-tests.sh --image ubuntu:jammy --scenario legacy

# keep the container of a failing scenario for inspection
tests/run-tests.sh --scenario fresh --keep
```

If `systemctl is-system-running` never settles inside the container, retry
with `CGROUP_MODE=private tests/run-tests.sh ...`, which starts the container
with a private cgroup namespace instead of the host one.

## Notes

- The lintian scenario only runs on `debian:trixie`; older lintian versions
  lack the tags and flags it uses.
- `debian:bullseye` reaches end of LTS on 2026-08-31. After that date the
  image build needs archive.debian.org sources before `apt-get update` works
  again.
