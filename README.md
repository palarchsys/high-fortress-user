# High-Fortress User

High-Fortress User prepares an Ubuntu 26.04 workstation. It installs the desktop programs, the local DNS resolver, the firewall, and the security checks.

The Ubuntu account already created on the machine is not replaced. The installer does not create a second account.

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git swaks tar
curl -fsSL https://raw.githubusercontent.com/palarchsys/high-fortress-user/main/install.sh | sudo bash
```

## Documentation

Click a flag to open all the information.

<table width="100%">
  <tr>
    <td width="25%"><a href="docs/en/README.md"><img src="docs/flags/en.svg" alt="English" width="100%"></a></td>
    <td width="25%"><a href="docs/fr/README.md"><img src="docs/flags/fr.svg" alt="Français" width="100%"></a></td>
    <td width="25%"><a href="docs/de/README.md"><img src="docs/flags/de.svg" alt="Deutsch" width="100%"></a></td>
    <td width="25%"><a href="docs/es/README.md"><img src="docs/flags/es.svg" alt="Español" width="100%"></a></td>
  </tr>
</table>
