[Full README](README.md)

# Surveillance

## AIDE

| Service that watches    | Zones                                               | What is alerted                                         | Mail command                                               |
| ----------------------- | --------------------------------------------------- | ------------------------------------------------------- | ---------------------------------------------------------- |
| aide.sh in boot-scan.sh | /etc/aide/aide.conf, database /var/lib/aide/aide.db | Changes, or a non-zero code that is not a clean result. | `sudo bash /opt/high-fortress-user/bin/aide-refresh-db.sh` |

Volatile paths, logs, caches and the cron report directories are excluded in `config/aide/aide.conf` so the baseline is not rewritten by those files.

The account block is appended after `!/home/`.

The last matching rule wins.

The watched paths are the workstation user's `.ssh/authorized_keys`, `.bashrc`, `.profile`, `.bash_profile`, `.config/autostart` and `.config/systemd/user`.

`.ssh/known_hosts` and `.ssh/known_hosts.old` are excluded.

## rkhunter

| Service that watches        | Zones                                           | What is alerted                                                             | Mail command      |
| --------------------------- | ----------------------------------------------- | --------------------------------------------------------------------------- | ----------------- |
| rkhunter.sh in boot-scan.sh | Package scan scope, plus the property baseline. | Warnings, a failed update, or `mirrors.dat modifié hors rkhunter --update`. | `sudo bash /opt/high-fortress-user/bin/rkhunter-refresh-db.sh` |

The mail command is attached to the warning mail. The stamp line and an update failure do not add it.

`/var/lib/rkhunter/db/mirrors.dat` is not ignored as a file. The stamp `/opt/high-fortress-user/cron/rkhunter-mirrors.sha256` is written only after `rkhunter --update` returns 0 or 2. A different hash is an alert. The check runs before the next `--update`.

Files in `/dev/shm` and the socket `/dev/log` are allowed.

They do not raise `Suspicious file types found in /dev`.

## chkrootkit

| Service that watches          | Zones                   | What is alerted                              | Mail command                                                                 |
| ----------------------------- | ----------------------- | -------------------------------------------- | ---------------------------------------------------------------------------- |
| chkrootkit.sh in boot-scan.sh | /usr/sbin/chkrootkit -q | Any remaining output after the ignore lists. | `sudo bash /opt/high-fortress-user/bin/chkrootkit-ignore-log.sh '<journal>'` |

Known lines live in `src/config/chkrootkit/patterns.ignore` and in `cron/chkrootkit.local.ignore`.

The local file is filled only by the command from the mail, and only for lines you recognize.

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

`clamav-event.sh` exits 0 before `hf_log_alert`.

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

The unit caps that pass at 50% of the whole machine.

The number is written when cron is configured.

A later change in the CPU count needs that step again.

`hfu-boot-chain.service` runs this pass, then the deferred scan, then the reboot notice.

The chain starts when `multi-user.target` is reached.

A failure of one pass does not stop the next one.

Brave, Thunderbird and Discord stay in this pass.

A file that cannot be read, with no `FOUND` line, does not send mail.

A `clamscan` process stopped by a signal sends mail.

The mail names the signal and each file that was not read.

The other files of the pass are still scanned.

Two crashes in a row stop the ClamAV pass.

The mail then says that the remaining files were not read.

## ClamAV idle scan

| Service that watches                 | Zones                                                                                                              | What is alerted                                                                                          | Mail command      |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------- | ----------------- |
| idle-scan.sh in hfu-idle-scan.timer | Accepted paths, except `.cache` and `snap`. | A new infection. A known pair in `scan-skip.seen` does not send mail again. | No command block. |

| Setting | Value |
| --- | --- |
| timer | `OnUnitActiveSec=1h`, `Persistent=false` |
| limits | `Nice` 19, `IOSchedulingClass=idle`, `CPUQuota` 50% of the whole machine |
| wait | `steam`, `steamwebhelper`, `lutris`, `heroic`, `wineserver`, `gamescope` |
| skipped directories | `shadercache`, `downloading` |
| files | executables of any size, and other files of 25M or less newer than `scan-skip.stamp` |
| stamp | advances only after a clean pass |
| covered | `/var/jeux`, `$HOME/.steam`, `$HOME/.local/share/Steam` |
| not covered | `$HOME/.cache`, `$HOME/snap` |

A `clamscan` process stopped by a signal sends mail.

The mail names the signal and each file that was not read.

The other files of the pass are still scanned.

Two crashes in a row stop the ClamAV pass.

The mail then says that the remaining files were not read.

The stamp stays in place.

## debsums

| Service that watches       | Zones                             | What is alerted                                        | Mail command                                                              |
| -------------------------- | --------------------------------- | ------------------------------------------------------ | ------------------------------------------------------------------------- |
| debsums.sh in boot-scan.sh | Packaged files, via `debsums -s`. | Each remaining package is reinstalled. The mail names the correction. | No command block. |

The mirrors.dat line is removed only when the live hash matches the stamp. There is no blanket ignore file for that path.

A changed line under `/usr/lib/*/perl-base/unicore/` from the package `perl-base` is dropped before this reinstall.

## auditd

| Service that watches | Zones                                          | What is alerted                                                  | Mail command |
| -------------------- | ---------------------------------------------- | ---------------------------------------------------------------- | ------------ |
| auditd               | /etc/audit/rules.d/00-high-fortress-user.rules | No mail of its own. The boot pass does not send an auditd alert. | None.        |

A watch with key `account` is added for `.ssh/authorized_keys`, `.bashrc`, `.profile`, `.bash_profile`, `.config/autostart` and `.config/systemd/user` when that path already exists.

A missing path is skipped, so `augenrules` still loads.

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
| ufw                  | Incoming denied, outgoing allowed, routed allowed, loopback allowed. SSH is limited to directly connected prefixes. | No mail of its own. | None.        |

## Lynis

| Service that watches               | Zones                     | What is alerted                                                 | Mail command |
| ---------------------------------- | ------------------------- | --------------------------------------------------------------- | ------------ |
| verify/workstation.sh and hf lynis | /var/log/lynis-report.dat | A score below 80 is a warning in the verify report, not a mail. | None.        |

`verify/workstation.sh` reports Secure Boot through `mokutil`.

It reports a LUKS root when `lsblk` shows `crypt` for the root source.

A missing one is a warning.

The installer leaves both unchanged.

## Reboot notice

| Service that watches | Zones | What is alerted | Mail command |
| --- | --- | --- | --- |
| reboot-notice.sh in hfu-reboot-notice.timer | `/var/run/reboot-required`, `/var/run/reboot-required.pkgs`, and `fwupdmgr get-updates` when that command exits 0 | A new set. The same digest in `reboot-notice.seen` does not send mail again. | No command block. |

The timer is `OnUnitActiveSec=6h`, with `Persistent=false`.

The boot chain runs this notice after the deferred scan.

`Nice` is 19, `IOSchedulingClass` is `idle`, and `CPUQuota` is 50% of the whole machine.

A running `steam`, `steamwebhelper`, `lutris`, `heroic`, `wineserver` or `gamescope` skips the mail.

That run leaves `reboot-notice.seen` unchanged.

The script does not reboot the machine.

The summary line is `Un redémarrage est utile. La machine n'a pas été redémarrée.`
