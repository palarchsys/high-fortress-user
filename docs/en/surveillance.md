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

| Exclusion | Rule |
| --- | --- |
| `scan-skip.paths` | Accepted paths only. |
| user `clamav` | `OnAccessExcludeUname clamav` |
| root | `OnAccessExcludeRootUID yes` |
| size | Files over 25M. |

The shipped file lists:

- `$HOME/.steam`
- `$HOME/.local/share/Steam`
- `$HOME/.cache`
- `$HOME/snap`
- `/var/jeux`

Brave, Thunderbird and Discord stay in the scan.

A path is accepted under the workstation user's home, below that home.

A path is accepted under `/var/jeux`, including `/var/jeux`.

| Refusal | Paths |
| --- | --- |
| system roots | `/`, `/home`, `/opt`, `/tmp`, `/etc`, `/usr`, `/var`, `/boot`, `/root` |
| whole home | `/home/<user>` |
| on-access directories | Downloads, Desktop |
| parent of those directories | a directory that contains Downloads or Desktop |
| anywhere else | a path outside that home and outside `/var/jeux` |

A refused line is ignored.

It is appended to `/opt/high-fortress-user/cron/security_logs/scan-skip.log`.

`/var/jeux` is an empty directory, mode 750, owned by the workstation user.

It is not a separate account.

`.clamav-quarantine-lock.*` is a move lock, not malware.

`clamav-event.sh` exits 0 before `log_alert`.

`scan-skip.sh` changes the list.

The command lines are in the README.

The same rewrite runs at the start of `boot-scan.sh`.

An existing `scan-skip.paths` is left in place when the installer runs again.

The rewrite replaces `OnAccessExcludePath` lines between `# BEGIN High-Fortress User scan-skip` and `# END High-Fortress User scan-skip`.

It restarts `clamav-daemon`, then `clamav-clamonacc.service` or `clamonacc.service`, when that block changes.

A hidden path gains `ALLOWHIDDENDIR` in `/etc/rkhunter.conf.local` when that line is missing.

Existing rkhunter lines stay.

## ClamAV boot scan

| Service that watches      | Zones             | What is alerted                        | Mail command      |
| ------------------------- | ----------------- | -------------------------------------- | ----------------- |
| clamav.sh in boot-scan.sh | /home, /opt, /tmp | Infections. A clean scan stays silent. | No command block. |

The scan prunes the on-access directories.

It prunes the accepted paths from `scan-skip.paths`.

It also prunes `proc`, `sys`, `dev`, `var/lib/docker`, `var/lib/libvirt`, `libvirt` and `snap-private-tmp`.

It reads files with `clamscan` inside the boot unit.

Brave, Thunderbird and Discord stay in this pass.

## ClamAV idle scan

| Service that watches                 | Zones                                                                                                              | What is alerted                                                                                          | Mail command      |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------- | ----------------- |
| idle-scan.sh in hfu-idle-scan.timer | Accepted paths, except `.cache` and `snap`. | A new infection. A known pair in `scan-skip.seen` does not send mail again. | No command block. |

| Setting | Value |
| --- | --- |
| timer | `OnBootSec=15min`, `OnUnitActiveSec=1h`, `Persistent=true` |
| limits | `Nice` 19, `IOSchedulingClass=idle`, `CPUQuota` 20% |
| wait | `steam`, `steamwebhelper`, `lutris`, `heroic`, `wineserver`, `gamescope` |
| skipped directories | `shadercache`, `downloading` |
| files | executables of any size, and other files of 25M or less newer than `scan-skip.stamp` |
| stamp | advances only after a clean pass |
| covered | `/var/jeux`, `$HOME/.steam`, `$HOME/.local/share/Steam` |
| not covered | `$HOME/.cache`, `$HOME/snap` |

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
