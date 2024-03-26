# linux
The official source of all available Linux packages of Sia software

As of this moment only Debian and other distros using 'Apt' as their package manager are supported.

The following packages are supported

- [renterd](https://github.com/SiaFoundation/renterd)
- [hostd](https://github.com/SiaFoundation/hostd)

## Adding the Repository

Add this repo to your sources by running the following command, replacing
`<distro>` and `<release>` with one of the following available distros and
their corresponding release.

- `debian`
    - `bookworm`
    - `bullseye`
    - `buster`
- `ubuntu`
    - `focal`
    - `jammy`
    - `mantic`
    - `noble`

```bash
sudo curl -fsSL https://linux.sia.tech/<distro>/gpg | sudo gpg --dearmor -o /usr/share/keyrings/siafoundation.gpg
echo "deb [signed-by=/usr/share/keyrings/siafoundation.gpg] https://linux.sia.tech/<distro> <release> main" | sudo tee -a /etc/apt/sources.list.d/siafoundation.list
```

### Release Channels

We also provide beta and nightly releases for those who want to test the latest
features and improvements. 

- Beta releases are release candidates that should be stable but have not been tested as thoroughly as the main releases.
- Nightly releases are built from the latest master branch and are not guaranteed to be stable.

To use these releases, replace `main` in the above command with `beta` or `nightly`. 

```bash
echo "deb [signed-by=/usr/share/keyrings/siafoundation.gpg] https://linux.sia.tech/<distro> <release> beta" | sudo tee -a /etc/apt/sources.list.d/siafoundation.list
```
or
```bash
echo "deb [signed-by=/usr/share/keyrings/siafoundation.gpg] https://linux.sia.tech/<distro> <release> nightly" | sudo tee -a /etc/apt/sources.list.d/siafoundation.list
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
$ sudo apt enable --now hostd
```

If you want to install a different package just replace `hostd` in the
commands with a different package name.
