# High-Fortress User

## Description

High-Fortress User prepares an Ubuntu 26.04 workstation. It installs the local DNS resolver, the firewall, and the security checks.

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

`install.sh` also installs `curl`, `ca-certificates` and `tar`, downloads branch `main`, and writes the sources to `/opt/high-fortress-user/src`. It then runs `scripts/configure.sh`. If `global.conf` already contains `HF_CONFIG_PREPARED=1`, `secrets.conf` exists, and `scripts/configure.sh --check` passes, it runs `scripts/run.sh` instead.

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
| From             | An e-mail address. `HF_WATCHDOG_MAIL` receives the same address.                                                                                       | Nothing on a first run.                                  |
| Mode test        | `0` or `1`.                                                                                                                                         | The current `HF_MODE_TEST`. The shipped default is `[1]`.   |

When alerts are enabled, `swaks` must receive an SMTP `250`. The success line is `Essai d'envoi accepté.` `HF_MAIL_ALERTS` becomes `1`. When alerts are disabled, the success line is `Alertes e-mail coupées. Les contrôles partiront sans envoi.` and the mail variables are cleared.

Values that are not asked are written from `hfu_set_config_default` and from the shipped `global.conf`. They are listed in [configuration.md](configuration.md). No random password is generated.

## Installed software and services

| Name                                            | Origin                                                                                  | Role                                                                                                                         |
| ----------------------------------------------- | --------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| openssh-server                                  | Ubuntu archive                                                                          | SSH server. Root login is refused. Password authentication stays enabled.                                                    |
| ufw                                             | Ubuntu archive                                                                          | Host firewall.                                                                                                               |
| usbguard, usbguard-notifier                     | Ubuntu archive                                                                          | Allows devices already plugged in, plus keyboards, mice and hubs. A new storage device waits for a desktop confirmation. |
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
| acct, sysstat, libpam-pwquality                 | Ubuntu archive                                                                          | Process accounting, activity stats, password quality.                                                                        |
| rng-tools-debian, haveged                       | Ubuntu archive                                                                          | Entropy sources.                                                                                                             |
| apt-listchanges, needrestart, apt-show-versions | Ubuntu archive                                                                          | Package change notices and restart checks.                                                                                   |

## What the machine does after installation

| Subject  | Behavior                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Firewall | `ufw default deny incoming`, `ufw default allow outgoing`, `ufw default allow routed`. Loopback is allowed in and out. SSH on the detected port is limited to each directly connected prefix. When no prefix is up, the limit from any source stays.                                                                                                                                                                                                                                                                                              |
| DNS      | Unbound listens on `127.0.0.1` and `::1`. systemd-resolved and NetworkManager are pointed at that resolver. IPv6 DNS stays enabled (`do-ip6: yes`).                                                                                                                                                                                                                                                                                                        |
| SSH      | `PermitRootLogin no`. `PasswordAuthentication yes`. `PubkeyAuthentication yes`. Banner `/etc/ssh/sshd_banner`. `MaxAuthTries 4`. `AllowTcpForwarding no`. `AllowAgentForwarding no`.                                                                                                                                                                                                                                                                                                                           |
| Kernel   | `/etc/sysctl.d/90-high-fortress-user.conf` is copied to `/etc/sysctl.d/99-zzz-high-fortress-user.conf`. IPv6 stays enabled. IPv6 redirects and source routing are refused. User namespaces stay enabled. `dccp`, `sctp`, `rds` and `tipc` are blacklisted. Unused filesystems are blacklisted. Core dumps are set to 0. `HFU_PAM_PASSWORD_MIN_LENGTH` is 12.                                                                                                          |
| AppArmor | `service/apparmor/userns.sh` adds `hfu-brave`, `hfu-discord`, `hfu-thunderbird`, and `hfu-steam` when Steam is not already covered.                                                                                                                                                                                                                                                                                            |
| Checks   | `hfu-boot-chain.timer` starts `hfu-boot-chain.service` when `multi-user.target` is reached (`OnBootSec=0`, `Persistent=false`). The chain runs `hfu-boot-scan.service`, then `hfu-idle-scan.service`, then `hfu-reboot-notice.service`. The boot pass runs AIDE, rkhunter, chkrootkit, ClamAV and debsums. `Nice` is `HF_WATCHDOG_LIMIT_NICE` (19), `IOSchedulingClass=idle`, `CPUQuota` is `HF_WATCHDOG_CPU_LIMIT` times the CPU count, so 50 is 50% of the whole machine. `/etc/cron.d/high-fortress-user` contains only `SHELL` and `PATH`. The user crontab is not modified. Mail is sent only when a check finds something and `HF_MAIL_ALERTS=1`. `hfu-idle-scan.timer` repeats the deferred scan every hour. `hfu-reboot-notice.timer` repeats the notice every 6 hours, and sends mail when a reboot is useful and no game is running. The rules are in [surveillance.md](surveillance.md). |
| Lynis    | `HF_LYNIS_MIN_SCORE` is 80. `verify/workstation.sh` accepts a `hardening_index` greater than or equal to that score.                                                                                                                                                                                                                                                                                                                                          |
| Journals | Install journals are `<source>/logs/install-YYYYMMDD-HHMMSS-user/`. Security journals are `/opt/high-fortress-user/cron/security_logs/`. Journald storage is persistent.                                                                                                                                                                                                                                                                                   |
| Packages | On amd64, the i386 architecture is enabled. CUPS is purged at the start of the installation. |
| USB          | Devices present at configure time stay allowed. Interface class `03` and class `09` stay allowed. A new storage device stays blocked until you accept it on the desktop. The `usb-storage` module stays available. |

## Alert emails

Mail is sent only when `HF_MAIL_ALERTS=1`, `HF_WATCHDOG_MAIL` is set, and `/opt/high-fortress-user/cron/bin/send.sh` is executable. A clean check does not send mail. If a journal line is unknown, do not run the command. Keep the mail.

A check that stops before its normal end sends mail.

The mail names the check.

It names the signal, or the exit code.

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

The message contains the summary and the journal excerpt. It does not add a command block. The check reinstalls each package still listed with `apt-get install --reinstall`. The mail names each restored package. The success line is `La somme correspond.`

A package whose checksum stays different, or whose reinstall fails, stays in the mail.

A line for `/var/lib/rkhunter/db/mirrors.dat` is dropped before this reinstall only when its live SHA-256 equals `/opt/high-fortress-user/cron/rkhunter-mirrors.sha256`.

A changed line under `/usr/lib/*/perl-base/unicore/` from the package `perl-base` is dropped before this reinstall.

The file shipped by Ubuntu does not match that package checksum.

### ClamAV on access

The message contains the signature, the file name, the original path and the quarantine path, then the note and a `sudo ls` command. The command is built for the quarantined file named in the mail. A file whose basename matches `.clamav-quarantine-lock.*` does not send mail. The script exits 0 before the journal and before `hf_log_alert`.

```bash
sudo ls -la -- /var/lib/clamav/quarantine/<file>
```

The example shows the form. The mail contains the real path, quoted. The command lists that file and does not put it back. `ls` prints the directory entry. There is no installer success line.

### ClamAV boot scan

The message contains the summary and the journal excerpt. This mail does not add a command block. The journal form is `/opt/high-fortress-user/cron/security_logs/clamav-YYYYMMDD-HHMMSS.log`.

A file that cannot be read, with no `FOUND` line, does not send mail.

The lines `Known viruses` and `Infected files` are not copied into the mail.

A `clamscan` process stopped by a signal sends mail.

The mail names the signal and each file that was not read.

The other files of the pass are still scanned.

Two crashes in a row stop the ClamAV pass.

The mail then says that the remaining files were not read.

### ClamAV idle scan

The message contains the summary and the journal excerpt.

This mail does not add a command block.

A signature and path already stored in `/opt/high-fortress-user/cron/scan-skip.seen` do not send mail again.

A `clamscan` process stopped by a signal sends mail.

The mail names the signal and each file that was not read.

The other files of the pass are still scanned.

Two crashes in a row stop the ClamAV pass.

The mail then says that the remaining files were not read.

The stamp stays in place.

The journal form is `/opt/high-fortress-user/cron/security_logs/idle-scan-YYYYMMDD-HHMMSS.log`.

### rkhunter

The warning mail contains the summary and the journal excerpt, then the note and the command block. The mail `mirrors.dat modifié hors rkhunter --update` does not add that block. An error mail does not add it either. The journal form is `/opt/high-fortress-user/cron/security_logs/rkhunter-YYYYMMDD-HHMMSS.log`.

```bash
sudo bash /opt/high-fortress-user/bin/rkhunter-refresh-db.sh
```

The command rebuilds the rkhunter property baseline from the current disk. The success line is `Base de propriétés rkhunter enregistrée.`

Files in `/dev/shm` and the socket `/dev/log` are allowed in `rkhunter.conf.local`.

They do not raise `Suspicious file types found in /dev`.

The excerpt keeps the warning line and the paths under it.

### Reboot notice

The message is `Un redémarrage est utile. La machine n'a pas été redémarrée.`

This mail does not add a command block.

The same package set does not send mail again.

A running game skips the mail and leaves the stamp unchanged.

The script does not reboot the machine.

The journal form is `/opt/high-fortress-user/cron/security_logs/reboot-notice-YYYYMMDD-HHMMSS.log`.

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

Checks the chain timer, the idle timer, ClamAV on access, and the mail path. Without `--no-send`, one probe is sent when alerts are enabled. The subject ends with `Contrôle`. The success line is `Résultat : OK`.

```bash
sudo bash verify/alerts.sh --no-send
```

The same check without sending the probe.

### verify/workstation.sh

```bash
sudo bash verify/workstation.sh "$PWD"
```

Runs the workstation verification. The closing line has the form `Check : N OK / N WARN / N FAIL`.

The same run checks SSH forwarding, the SSH firewall rule, USBGuard, the sudo timeout and `hfu-reboot-notice.timer`.

### Check after boot

```bash
sudo bash /opt/high-fortress-user/bin/boot-check.sh
```

Checks the boot security services and the three passes of this session.

The success line is `Contrôle de démarrage : OK`.

A pass still running prints `Contrôle de démarrage : en cours` and exits 1.

A gap prints `Contrôle de démarrage : écarts` and exits 1.

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

### Excluded scan paths

```bash
sudo bash /opt/high-fortress-user/bin/scan-skip.sh list
sudo bash /opt/high-fortress-user/bin/scan-skip.sh add /var/jeux/steam
sudo bash /opt/high-fortress-user/bin/scan-skip.sh del /var/jeux/steam
```

The list file is `/opt/high-fortress-user/src/config/clamav/scan-skip.paths`.

An existing list stays in place when the installer runs again.

A list still stored in `/opt/high-fortress-user/cron/scan-skip.paths` is copied once, when the new file is still the template.

| Action | Printed line |
| --- | --- |
| `list` | one accepted path per line |
| `add` | `Chemin ajouté : <path>` |
| already present | `Ce chemin est déjà exclu : <path>` |
| `del` | `Chemin retiré : <path>` |
| refused | `Chemin refusé : <path>` |

A refused path leaves the file unchanged.

The command rewrites `/etc/clamav/clamd.conf`.

It restarts `clamav-daemon`, then `clamav-clamonacc.service` or `clamonacc.service`, when the exclude block changes.

Accepted paths, the shipped list and refusals are in [surveillance.md](surveillance.md).

## Detailed pages

| Subject                       | Page                                 |
| ----------------------------- | ------------------------------------ |
| General and service variables | [configuration.md](configuration.md) |
| Watch tools                   | [surveillance.md](surveillance.md)   |
| Installed tree                | [architecture.md](architecture.md)   |
| Installed files               | [files.md](files.md)                 |
| Journals                      | [logs.md](logs.md)                   |
