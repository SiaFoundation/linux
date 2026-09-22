# linux
The official source of all available Linux packages of Sia software

As of this moment only Debian and other distros using 'Apt' as their package manager are supported.

The following packages are supported

- [renterd](https://github.com/SiaFoundation/renterd)
- [hostd](https://github.com/SiaFoundation/hostd)
- [sia-s3d](https://github.com/SiaFoundation/s3d)
- [walletd](https://github.com/SiaFoundation/walletd)

## Adding the Repository

Add this repo to your sources by running the following command, replacing
`<distro>` and `<release>` with one of the following available distros and
their corresponding release.

- `debian`
    - `trixie`
    - `bookworm`
- `ubuntu`
    - `resolute`
    - `questing`
    - `noble`
    - `jammy`

```bash
sudo curl -fsSL https://linux.sia.tech/<distro>/gpg | sudo gpg --dearmor -o /usr/share/keyrings/siafoundation.gpg
echo "deb [signed-by=/usr/share/keyrings/siafoundation.gpg] https://linux.sia.tech/<distro> <release> main" | sudo tee -a /etc/apt/sources.list.d/siafoundation.list
```

## Installing Packages

After that, you can install any of the available packages (e.g. `hostd`) like this:

```bash
# install
$ sudo apt install hostd
```

All packages also ship with a systemd service that you can use to keep hostd
running in the background:

```bash
# create working dir
$ sudo mkdir -p /var/lib/hostd
$ cd /var/lib/hostd

# configure hostd
$ hostd config

# enable hostd systemd service
$ sudo systemctl enable --now hostd
```

If you want to install a different package just replace `hostd` in the
commands with a different package name.

### s3d

Install this package with `sudo apt install sia-s3d`. The command and systemd
service are named `s3d`. The apt name carries the prefix because Debian and
Ubuntu already ship an unrelated package called `s3d`.

s3d needs to be registered with the indexer before the daemon can start.
`s3d login` walks you through the initial configuration and registers this
instance with the indexer. The service runs as the `s3d` user, which owns
`/etc/s3d` and `/var/lib/s3d`, so run the setup commands as that user and from
the data directory. s3d probes the working directory for a config file first and
stops if it cannot read one. Run the following commands once to register this
instance and start the service:

```bash
# configure s3d and register it with the indexer
$ sudo -u s3d sh -c 'cd /var/lib/s3d && s3d login'

# create a user and an S3 access key
$ sudo -u s3d sh -c 'cd /var/lib/s3d && s3d users create <username>'
$ sudo -u s3d sh -c 'cd /var/lib/s3d && s3d keys create <username>'

# enable s3d systemd service
$ sudo systemctl enable --now s3d
```

The service logs to the journal, so read it with `journalctl -u s3d`. The unit
passes `-log.file.enabled=false -log.stdout.enableANSI=false`, which overrides
the config file. To write a log file instead, run `sudo systemctl edit s3d` and
add both lines below. The empty one is required before setting a new command.

```ini
[Service]
ExecStart=
ExecStart=/usr/bin/s3d -log.file.enabled=true
```
