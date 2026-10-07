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

Excluded: `$HOME/.steam`, `$HOME/.local/share/Steam`, the user `clamav`, root (`OnAccessExcludeRootUID yes`), and files over 25M. `.clamav-quarantine-lock.*` is a move lock, not malware, so `clamav-event.sh` exits 0 before `log_alert`.

## ClamAV boot scan

| Service that watches      | Zones             | What is alerted                        | Mail command      |
| ------------------------- | ----------------- | -------------------------------------- | ----------------- |
| clamav.sh in boot-scan.sh | /home, /opt, /tmp | Infections. A clean scan stays silent. | No command block. |

The scan prunes the on-access directories and the names `BraveSoftware`, `.config/discord`, `.thunderbird`, `thunderbird`, `libvirt` and `snap-private-tmp`, so those trees are not scanned twice.

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
