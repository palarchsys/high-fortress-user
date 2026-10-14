[Full README](README.md)

# Surveillance

## AIDE

| Service that watches    | Zones                                               | What is alerted                                         | Mail command                                               |
| ----------------------- | --------------------------------------------------- | ------------------------------------------------------- | ---------------------------------------------------------- |
| aide.sh in boot-scan.sh | /etc/aide/aide.conf, database /var/lib/aide/aide.db | Changes, or a non-zero code that is not a clean result. | `sudo bash /opt/high-fortress-user/bin/aide-refresh-db.sh` |

Volatile paths, logs, caches and the cron report directories are excluded in `service/aide/aide.conf` so the baseline is not rewritten by those files.

## rkhunter

| Service that watches        | Zones                                           | What is alerted                                                             | Mail command      |
| --------------------------- | ----------------------------------------------- | --------------------------------------------------------------------------- | ----------------- |
| rkhunter.sh in boot-scan.sh | Package scan scope, plus the property baseline. | Warnings, a failed update, or `mirrors.dat modifié hors rkhunter --update`. | No command block. |

`/var/lib/rkhunter/db/mirrors.dat` is not ignored as a file. The stamp `/opt/high-fortress-user/cron/rkhunter-mirrors.sha256` is written only after `rkhunter --update` returns 0 or 2. A different hash is an alert. The check runs before the next `--update`.

## chkrootkit

| Service that watches          | Zones                   | What is alerted                              | Mail command                                                                 |
| ----------------------------- | ----------------------- | -------------------------------------------- | ---------------------------------------------------------------------------- |
| chkrootkit.sh in boot-scan.sh | /usr/sbin/chkrootkit -q | Any remaining output after the ignore lists. | `sudo bash /opt/high-fortress-user/bin/chkrootkit-ignore-log.sh '<journal>'` |

Known lines live in `cron/bin/chkrootkit.ignore` and in `cron/chkrootkit.local.ignore`. The local file is filled only by the command from the mail, and only for lines you recognize.

## ClamAV on access

| Service that watches            | Zones                  | What is alerted                            | Mail command                       |
| ------------------------------- | ---------------------- | ------------------------------------------ | ---------------------------------- |
| clamonacc, then clamav-event.sh | Downloads and Desktop. | A real detection. Lock files do not alert. | `sudo ls -la -- <quarantine path>` |

Excluded from the on-access scan: every accepted path in `/opt/high-fortress-user/cron/scan-skip.paths`, the user `clamav`, root (`OnAccessExcludeRootUID yes`), and files over 25M. The file shipped at install lists `$HOME/.steam`, `$HOME/.local/share/Steam`, `$HOME/.cache`, `$HOME/snap` and `/var/jeux`. Brave, Thunderbird and Discord are not in that list. A line that is relative, empty, or exactly `/`, `/home`, `/opt`, `/tmp`, `/etc`, `/usr`, `/var`, `/boot`, `/root`, `/home/<user>`, Downloads or Desktop is ignored and appended to `/opt/high-fortress-user/cron/security_logs/scan-skip.log`. `/var/jeux` is an empty directory, mode 750, owned by the workstation user. It is not a separate account. `.clamav-quarantine-lock.*` is a move lock, not malware, so `clamav-event.sh` exits 0 before `log_alert`.

Change the list with `scan-skip.sh`. The same rewrite runs at the start of `boot-scan.sh`. An existing `scan-skip.paths` is left in place when the installer runs again.

```bash
sudo bash /opt/high-fortress-user/bin/scan-skip.sh list
sudo bash /opt/high-fortress-user/bin/scan-skip.sh add /var/jeux/steam
sudo bash /opt/high-fortress-user/bin/scan-skip.sh del /var/jeux/steam
```

`list` prints one accepted path per line. `add` prints `Chemin ajouté : <path>`. A path already present prints `Ce chemin est déjà exclu : <path>`. `del` prints `Chemin retiré : <path>`. A refused path prints `Chemin refusé : <path>`. The command rewrites the `OnAccessExcludePath` lines between `# BEGIN High-Fortress User scan-skip` and `# END High-Fortress User scan-skip` in `/etc/clamav/clamd.conf`. `clamav-daemon` is reloaded only when that block changes. A hidden path gains an `ALLOWHIDDENDIR` line in `/etc/rkhunter.conf.local` when that line is missing. Existing rkhunter lines stay.

## ClamAV boot scan

| Service that watches      | Zones             | What is alerted                        | Mail command      |
| ------------------------- | ----------------- | -------------------------------------- | ----------------- |
| clamav.sh in boot-scan.sh | /home, /opt, /tmp | Infections. A clean scan stays silent. | No command block. |

The scan prunes the on-access directories and the accepted paths from `scan-skip.paths`. It also prunes `proc`, `sys`, `dev`, `var/lib/docker`, `var/lib/libvirt`, `libvirt` and `snap-private-tmp`. It reads the files with `clamscan` in the boot unit. It does not call `clamdscan`. Brave, Thunderbird and Discord stay in this pass.

## ClamAV idle scan

| Service that watches                 | Zones                                                                                                              | What is alerted                                                                                          | Mail command      |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------- | ----------------- |
| idle-scan.sh in hfu-idle-scan.timer  | Accepted paths in `scan-skip.paths`, except a directory whose last component is `.cache` or `snap`.               | A new infection. A signature and path already stored in `/opt/high-fortress-user/cron/scan-skip.seen` do not send mail again. | No command block. |

`hfu-idle-scan.timer` uses `OnBootSec=15min`, `OnUnitActiveSec=1h` and `Persistent=true`. `Nice` is `WATCHDOG_LIMIT_NICE` (19), `IOSchedulingClass=idle`, and `CPUQuota` is `WATCHDOG_CPU_LIMIT` (20%). The pass exits 0 without scanning while `steam`, `steamwebhelper`, `lutris`, `heroic`, `wineserver` or `gamescope` is running. It skips directories named `shadercache` and `downloading`. It scans executable files at any size, and other files of 25M or less that are newer than `/opt/high-fortress-user/cron/scan-skip.stamp`. The stamp advances only after a clean pass. `/var/jeux`, `$HOME/.steam` and `$HOME/.local/share/Steam` are covered. `$HOME/.cache` and `$HOME/snap` are not.

## debsums

| Service that watches       | Zones                             | What is alerted                                        | Mail command                                                              |
| -------------------------- | --------------------------------- | ------------------------------------------------------ | ------------------------------------------------------------------------- |
| debsums.sh in boot-scan.sh | Packaged files, via `debsums -s`. | Changed packaged files that are not on an ignore list. | `sudo bash /opt/high-fortress-user/bin/debsums-ignore-log.sh '<journal>'` |

The mirrors.dat line is removed only when the live hash matches the stamp. There is no blanket ignore file for that path.

## auditd

| Service that watches | Zones                                          | What is alerted                                                  | Mail command |
| -------------------- | ---------------------------------------------- | ---------------------------------------------------------------- | ------------ |
| auditd               | /etc/audit/rules.d/00-high-fortress-user.rules | No mail of its own. The boot pass does not send an auditd alert. | None.        |

## Fail2Ban

| Service that watches | Zones                    | What is alerted     | Mail command |
| -------------------- | ------------------------ | ------------------- | ------------ |
| fail2ban             | /etc/fail2ban/jail.local | No mail of its own. | None.        |

## CrowdSec

| Service that watches | Zones          | What is alerted     | Mail command |
| -------------------- | -------------- | ------------------- | ------------ |
| crowdsec             | /etc/crowdsec/ | No mail of its own. | None.        |

## UFW

| Service that watches | Zones                                                                | What is alerted     | Mail command |
| -------------------- | -------------------------------------------------------------------- | ------------------- | ------------ |
| ufw                  | Incoming denied, outgoing allowed, routed allowed, loopback allowed. | No mail of its own. | None.        |

## Lynis

| Service that watches               | Zones                     | What is alerted                                                 | Mail command |
| ---------------------------------- | ------------------------- | --------------------------------------------------------------- | ------------ |
| verify/workstation.sh and hf lynis | /var/log/lynis-report.dat | A score below 80 is a warning in the verify report, not a mail. | None.        |
