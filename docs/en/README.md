# High-Fortress User

## Description

High-Fortress User prepares an Ubuntu 26.04 workstation. It installs the desktop programs, the local DNS resolver, the firewall, and the security checks.

The Ubuntu account already created on the machine is not replaced. The installer does not create a second account.

`secrets.conf` stays on the machine. Do not copy it into a message, a ticket, or a repository.

## Before you start

### System

Ubuntu 26.04. A fresh installation is preferred. Use a local console or the existing graphical session. The machine needs Internet access.

### Access

You need `sudo` for `./hf configure`, `./hf run`, and the checks.

### External needs

| Need                 | Link and procedure                                                                                                                                                                                                   |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ubuntu Pro token     | Required. Open [https://ubuntu.com/pro/dashboard](https://ubuntu.com/pro/dashboard) and copy the token. `configure.sh` accepts letters and digits only, length 6 to 100, with no space.                              |
| Application password | Asked only if you enable mail alerts. Use the application password of the mail provider. Never type the account password. Length 8 to 128. Spaces typed in the prompt are removed.                                   |
| SMTP server          | Asked only if alerts are enabled. Form `host:port`. The example in `configure.sh` is `smtp-mail.outlook.com:587`. Brackets are refused. `swaks` sends one test message. The success line is `Essai d'envoi accepté.` |

## Installation

### Curl

`install.sh` also installs `curl`, `ca-certificates` and `tar`, downloads branch `main`, and writes the sources to `/opt/high-fortress-user/src`. It then runs `scripts/configure.sh`. If `global.conf` already contains `HF_PREPARED=1`, `secrets.conf` exists, and `scripts/configure.sh --check` passes, it runs `scripts/run.sh` instead.

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git swaks tar
curl -fsSL https://raw.githubusercontent.com/palarchsys/high-fortress-user/main/install.sh | sudo bash
```

### Clone

The clone stays in the directory created by `git clone`. `sudo ./hf configure` runs in that directory. The curl installer is the command that copies the sources to `/opt/high-fortress-user/src`.

```bash
git clone https://github.com/palarchsys/high-fortress-user
cd high-fortress-user
sudo ./hf configure
```

## What configure.sh does

`sudo ./hf configure` asks the questions below, writes `global.conf` mode `644` and `secrets.conf` mode `600` as root, then starts `scripts/run.sh`. `secrets.conf` does not leave the machine.

| Question         | Expected answer                                                                                                                                     | Enter keeps                                              |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| Jeton Ubuntu Pro | Letters and digits, 6 to 100, no space. Required.                                                                                                   | A token already stored. A first run has no stored token. |
| Activer          | `Y` or `y` enables alerts. `n` or `non` disables them. Any other answer prints `Répondez Y ou n.`                                                   | Nothing. The question has no default.                    |
| Serveur          | `host:port`, for example `smtp-mail.outlook.com:587`. No brackets. Asked only when alerts are enabled.                                              | Nothing on a first run.                                  |
| Login            | An e-mail address.                                                                                                                                  | Nothing on a first run.                                  |
| Password         | The provider application password, 8 to 128 characters. Spaces are removed. Quotes, `$`, `\` and backticks are refused. Never the account password. | Nothing. A second line asks for confirmation.            |
| From             | An e-mail address. `WATCHDOG_MAIL` receives the same address.                                                                                       | Nothing on a first run.                                  |
| Mode test        | `0` or `1`.                                                                                                                                         | The current `MODE_TEST`. The shipped default is `[1]`.   |

When alerts are enabled, `swaks` must receive an SMTP `250`. The success line is `Essai d'envoi accepté.` `HF_MAIL_ALERTS` becomes `1`. When alerts are disabled, the success line is `Alertes e-mail coupées. Les contrôles partiront sans envoi.` and the mail variables are cleared.

Values that are not asked are written from `hfu_config_set_builtin_defaults` and from the shipped `global.conf`. They are listed in [configuration.md](configuration.md). No random password is generated.

## Installed software and services

| Name                                            | Origin                                                                                  | Role                                                                                                                         |
| ----------------------------------------------- | --------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| openssh-server                                  | Ubuntu archive                                                                          | SSH server. Root login is refused. Password authentication stays enabled.                                                    |
| ufw                                             | Ubuntu archive                                                                          | Host firewall.                                                                                                               |
| fail2ban                                        | Ubuntu archive                                                                          | Bans repeated authentication failures.                                                                                       |
| auditd                                          | Ubuntu archive                                                                          | Writes audit rules for selected paths.                                                                                       |
| rkhunter                                        | Ubuntu archive                                                                          | Rootkit and file-property check.                                                                                             |
| chkrootkit                                      | Ubuntu archive                                                                          | Rootkit check. The binary is `/usr/sbin/chkrootkit`.                                                                         |
| clamav                                          | Ubuntu archive                                                                          | On-access scan and boot scan.                                                                                                |
| crowdsec                                        | https://packagecloud.io/crowdsec/crowdsec/any any main                                  | Local security decisions.                                                                                                    |
| debsums                                         | Ubuntu archive                                                                          | Checksums of packaged files.                                                                                                 |
| unbound                                         | Ubuntu archive                                                                          | Local DNS resolver on `127.0.0.1` and `::1`, port 53.                                                                        |
| apparmor                                        | Ubuntu archive, plus `service/apparmor/userns.sh`                                       | Distribution profiles, plus userns profiles for Brave, Discord, Thunderbird, and Steam when no profile already covers Steam. |
| aide                                            | Ubuntu archive                                                                          | File integrity database `/var/lib/aide/aide.db`.                                                                             |
| unattended-upgrades                             | Ubuntu archive                                                                          | Security origins and the Thunderbird origin. `Automatic-Reboot` is `false`.                                                  |
| postfix                                         | Ubuntu archive, only when `HF_MAIL_ALERTS=1`                                            | Sends alert mail.                                                                                                            |
| lynis                                           | https://packages.cisofy.com/community/lynis/deb/ stable main                            | Hardening audit. The key is `https://packages.cisofy.com/keys/cisofy-software-public.key`.                                   |
| ubuntu-pro-client                               | Ubuntu archive                                                                          | Attaches the Ubuntu Pro token.                                                                                               |
| brave-browser                                   | https://brave-browser-apt-release.s3.brave.com/brave-browser.sources                    | Web browser.                                                                                                                 |
| thunderbird                                     | https://packages.mozilla.org/apt suite thunderbird-deb                                  | Mail client from Mozilla packages, not the snap.                                                                             |
| keepassxc                                       | Ubuntu archive                                                                          | Password database.                                                                                                           |
| discord                                         | https://discord.com/api/download?platform=linux&format=deb                              | Discord client.                                                                                                              |
| Vencord                                         | https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli-linux | Installed into the Discord client by `service/desktop/install.sh`.                                                           |
| acct, sysstat, libpam-pwquality                 | Ubuntu archive                                                                          | Process accounting, activity stats, password quality.                                                                        |
| rng-tools-debian, haveged                       | Ubuntu archive                                                                          | Entropy sources.                                                                                                             |
| apt-listchanges, needrestart, apt-show-versions | Ubuntu archive                                                                          | Package change notices and restart checks.                                                                                   |

## What the machine does after installation

| Subject  | Behavior                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Firewall | `ufw default deny incoming`, `ufw default allow outgoing`, `ufw default allow routed`. Loopback is allowed in and out. No other incoming allow rule is added.                                                                                                                                                                                                                                                                                              |
| DNS      | Unbound listens on `127.0.0.1` and `::1`. systemd-resolved and NetworkManager are pointed at that resolver. IPv6 DNS stays enabled (`do-ip6: yes`).                                                                                                                                                                                                                                                                                                        |
| SSH      | `PermitRootLogin no`. `PasswordAuthentication yes`. `PubkeyAuthentication yes`. Banner `/etc/ssh/sshd_banner`. `MaxAuthTries 4`.                                                                                                                                                                                                                                                                                                                           |
| Kernel   | `/etc/sysctl.d/90-high-fortress-user.conf` is copied to `/etc/sysctl.d/99-zzz-high-fortress-user.conf`. IPv6 stays enabled. IPv6 redirects and source routing are refused. User namespaces stay enabled. `dccp`, `sctp`, `rds` and `tipc` are blacklisted. Unused filesystems are blacklisted. Core dumps are set to 0. `PWQUALITY_MINLEN` is 12.                                                                                                          |
| AppArmor | Distribution profiles stay. `service/apparmor/userns.sh` adds `hfu-brave`, `hfu-discord`, `hfu-thunderbird`, and `hfu-steam` when Steam is not already covered.                                                                                                                                                                                                                                                                                            |
| Checks   | `hfu-boot-scan.timer` runs `boot-scan.sh` 2 minutes after boot (`OnBootSec=2min`, `Persistent=false`). The pass runs AIDE, rkhunter, chkrootkit, ClamAV and debsums. `Nice` is `WATCHDOG_LIMIT_NICE` (19), `IOSchedulingClass=idle`, `CPUQuota` is `WATCHDOG_CPU_LIMIT` (20%). `/etc/cron.d/high-fortress-user` contains only `SHELL` and `PATH`. The user crontab is not modified. Mail is sent only when a check finds something and `HF_MAIL_ALERTS=1`. |
| Lynis    | `LYNIS_MIN_SCORE` is 80. `verify/workstation.sh` accepts a `hardening_index` greater than or equal to that score.                                                                                                                                                                                                                                                                                                                                          |
| Journals | Install journals are `<source>/logs/install-YYYYMMDD-HHMMSS-user/`. Security journals are `/opt/high-fortress-user/cron/security_logs/`. Journald storage is persistent.                                                                                                                                                                                                                                                                                   |
| Packages | The Firefox and Thunderbird snaps are removed. `snapd` is kept. The `firefox` package is held. On amd64, the i386 architecture is enabled. Steam is not installed by this program.                                                                                                                                                                                                                                                                         |

## Alert emails

Mail is sent only when `HF_MAIL_ALERTS=1`, `WATCHDOG_MAIL` is set, and `/opt/high-fortress-user/cron/bin/send.sh` is executable. A clean check does not send mail. If a journal line is unknown, do not run the command. Keep the mail.

### AIDE

The message contains the summary line and an excerpt of the journal, then the note and the command block. The journal path in the mail is the real file. The form is `/opt/high-fortress-user/cron/security_logs/aide-YYYYMMDD-HHMMSS.log`.

```bash
sudo bash /opt/high-fortress-user/bin/aide-refresh-db.sh
```

The command rebuilds the AIDE baseline from the current disk. The success line is `Base de référence AIDE enregistrée.`

### chkrootkit

The message contains the summary and the journal excerpt, then the note and the command. The example below shows the form. The mail contains the real path.

```bash
sudo bash /opt/high-fortress-user/bin/chkrootkit-ignore-log.sh '/opt/high-fortress-user/cron/security_logs/chkrootkit-YYYYMMDD-HHMMSS.log'
```

The command records the lines of that journal into `/opt/high-fortress-user/cron/chkrootkit.local.ignore`. The success line is `Aucune nouvelle détection à enregistrer.` when nothing new is added, or `N détection(s) enregistrée(s) dans /opt/high-fortress-user/cron/chkrootkit.local.ignore`.

### debsums

The message contains the summary and the journal excerpt, then the note and the command. The example below shows the form. The mail contains the real path.

```bash
sudo bash /opt/high-fortress-user/bin/debsums-ignore-log.sh '/opt/high-fortress-user/cron/security_logs/debsums-YYYYMMDD-HHMMSS.log'
```

The command records the lines of that journal into `/opt/high-fortress-user/cron/debsums.local.ignore`. The success line is `Aucune nouvelle détection à enregistrer.` or `N détection(s) enregistrée(s) dans /opt/high-fortress-user/cron/debsums.local.ignore`. A line for `/var/lib/rkhunter/db/mirrors.dat` is dropped before the mail only when its live SHA-256 equals `/opt/high-fortress-user/cron/rkhunter-mirrors.sha256`. Any other content stays in the mail. Do not ignore the whole file.

### ClamAV on access

The message contains the signature, the file name, the original path and the quarantine path, then the note and a `sudo ls` command. The command is built for the quarantined file named in the mail. A file whose basename matches `.clamav-quarantine-lock.*` does not send mail. The script exits 0 before the journal and before `log_alert`.

```bash
sudo ls -la -- /var/lib/clamav/quarantine/<file>
```

The example shows the form. The mail contains the real path, quoted. The command lists that file and does not put it back. `ls` prints the directory entry. There is no installer success line.

### ClamAV boot scan

The message contains the summary and the journal excerpt. This mail does not add a command block. The journal form is `/opt/high-fortress-user/cron/security_logs/clamav-YYYYMMDD-HHMMSS.log`.

### rkhunter

The message contains the summary and the journal excerpt. This mail does not add a command block. A stamp mismatch adds the line `mirrors.dat modifié hors rkhunter --update`. That line is not a command. The journal form is `/opt/high-fortress-user/cron/security_logs/rkhunter-YYYYMMDD-HHMMSS.log`.

## Commands after installation

Run these commands from the source directory (`/opt/high-fortress-user/src` after the curl installer, or the clone directory).

### hf check

```bash
sudo ./hf check
```

Checks `global.conf` and `secrets.conf`. The success line is `Configuration conforme`. `secrets.conf` is mode `600`, so `sudo` is required to read it.

### hf run

```bash
sudo ./hf run
```

Runs the installation from the prepared files. The installer refuses to start when the check does not pass.

### verify/alerts.sh

```bash
sudo bash verify/alerts.sh
```

Checks the boot timer, ClamAV on access, and the mail path. Without `--no-send`, one probe is sent when alerts are enabled. The subject ends with `Contrôle`. The success line is `Résultat : OK`.

```bash
sudo bash verify/alerts.sh --no-send
```

The same check without sending the probe.

### verify/workstation.sh

```bash
sudo bash verify/workstation.sh "$PWD"
```

Runs the workstation verification. The closing line has the form `Check : N OK / N WARN / N FAIL`.

### hf lynis

```bash
sudo ./hf lynis
```

Runs `lynis audit system --quick --no-colors` and writes the report under `<source>/logs/lynis-<stamp>/`.

### AIDE baseline

```bash
sudo bash /opt/high-fortress-user/bin/aide-refresh-db.sh
```

Rebuilds `/var/lib/aide/aide.db`. The success line is `Base de référence AIDE enregistrée.`

### rkhunter mirror stamp

```bash
sudo bash /opt/high-fortress-user/cron/bin/record-mirrors.sh save
```

Writes the SHA-256 of `/var/lib/rkhunter/db/mirrors.dat` to `/opt/high-fortress-user/cron/rkhunter-mirrors.sha256` in mode `600`. `rkhunter.sh` saves this stamp only after `rkhunter --update` returns 0 or 2.

## Detailed pages

| Subject                       | Page                                 |
| ----------------------------- | ------------------------------------ |
| General and service variables | [configuration.md](configuration.md) |
| Watch tools                   | [surveillance.md](surveillance.md)   |
| Installed tree                | [architecture.md](architecture.md)   |
| Installed files               | [files.md](files.md)                 |
| Journals                      | [logs.md](logs.md)                   |
