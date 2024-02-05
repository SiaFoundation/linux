# linux
The official source of all available Linux packages of Sia software

As of this moment only Debian and other distros using 'Apt' as their package manager are supported.

The following packages are supported

- [renterd](https://github.com/SiaFoundation/renterd)
- [hostd](https://github.com/SiaFoundation/hostd)

Simply add this repo to your sources by running the following command

```bash
sudo curl -fsSL https://linux.sia.tech/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/siafoundation.gpg
echo "deb [signed-by=/usr/share/keyrings/siafoundation.gpg] https://linux.sia.tech/debian stable main" | sudo tee -a /etc/apt/sources.list.d/siafoundation.list
```
