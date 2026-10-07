[Full README](README.md)

# Files

Each row is a file the installer writes, with the mode the script sets. Files inside Ubuntu packages are not listed one by one: the repository does not name them.

| Path                                                    | Role                                                                                             | Mode                         |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | ---------------------------- |
| /opt/high-fortress-user                                 | Runtime root.                                                                                    | 755                          |
| /opt/high-fortress-user/secrets                         | Directory reserved by the installer. `secrets.conf` is not stored here.                          | 700                          |
| /opt/high-fortress-user/src/config/global.conf                 | Prepared configuration when the curl installer was used. Same file sits in `config/` in a clone. | 644                          |
| /opt/high-fortress-user/src/config/secrets.conf                | Secrets written by configure.sh. Stays on the machine.                                           | 600                          |
| /opt/high-fortress-user/src/hf                          | Launcher.                                                                                        | 755                          |
| /opt/high-fortress-user/bin/aide-refresh-db.sh          | Rebuilds the AIDE baseline.                                                                      | 755                          |
| /opt/high-fortress-user/bin/chkrootkit-ignore-log.sh    | Records recognized chkrootkit lines.                                                             | 755                          |
| /opt/high-fortress-user/bin/debsums-ignore-log.sh       | Records recognized debsums lines.                                                                | 755                          |
| /opt/high-fortress-user/cron/bin/*.sh                   | Watch scripts and mail.sh. Owner root.                                                           | 750                          |
| /opt/high-fortress-user/cron/bin/mail.html              | Mail template.                                                                                   | 644                          |
| /opt/high-fortress-user/cron/bin/chkrootkit.ignore      | Shipped chkrootkit patterns.                                                                     | 664                          |
| /opt/high-fortress-user/cron/mail.conf                  | HF_MAIL_ALERTS, WATCHDOG_MAIL, PROJECT_NAME, MAIL_TEMPLATE.                                      | 600                          |
| /opt/high-fortress-user/cron/rkhunter-mirrors.sha256    | Stamp of mirrors.dat after a successful update.                                                  | 600                          |
| /etc/cron.d/high-fortress-user                          | SHELL and PATH only.                                                                             | 600                          |
| /etc/systemd/system/hfu-boot-scan.service               | Boot scan unit.                                                                                  | 644                          |
| /etc/systemd/system/hfu-boot-scan.timer                 | Starts the scan 2 minutes after boot.                                                            | 644                          |
| /etc/ssh/sshd_config.d/00-high-fortress-user.conf       | SSH policy for this workstation.                                                                 | 644                          |
| /etc/ssh/sshd_banner                                    | Login banner.                                                                                    | 644                          |
| /etc/aide/aide.conf                                     | AIDE policy with CONFIG_BASE_DIR substituted.                                                    | written by redirection       |
| /var/lib/aide/aide.db                                   | AIDE baseline.                                                                                   | created by aide --init       |
| /etc/clamav/clamd.conf                                  | On-access paths appended by service/clamav/configure.sh.                                         | package file, lines appended |
| /var/lib/clamav/quarantine                              | Quarantine directory.                                                                            | 750                          |
| /etc/sudoers.d/high-fortress-user-clamav                | Allows the VirusEvent sudo call.                                                                 | 440                          |
| /etc/systemd/system/clamav-clamonacc.service.d/hfu.conf | Points clamonacc at the quarantine directory. The unit name is the packaged one.                 | written by redirection       |
| /etc/unbound/unbound.conf.d/high-fortress-user.conf     | Local resolver.                                                                                  | 644                          |
| /etc/systemd/system/hfu-unbound-root-hints.service      | Refreshes root hints.                                                                            | 644                          |
| /etc/systemd/system/hfu-unbound-root-hints.path         | Path unit for root hints.                                                                        | 644                          |
| /etc/apt/sources.list.d/lynis.list                      | CISOfy Lynis origin.                                                                             | 644                          |
| /etc/apt/keyrings/cisofy-software.gpg                   | Lynis key.                                                                                       | 644                          |
| /etc/apt/sources.list.d/mozilla.sources                 | Thunderbird origin.                                                                              | 644                          |
| /etc/apt/sources.list.d/brave-browser-release.sources   | Brave origin.                                                                                    | 644                          |
| /etc/apt/apt.conf.d/51high-fortress-user                | Unattended upgrades, reboot off.                                                                 | written by redirection       |
| /etc/sysctl.d/90-high-fortress-user.conf                | Workstation sysctl.                                                                              | 644                          |
| /etc/sysctl.d/99-zzz-high-fortress-user.conf            | Copy of the sysctl file applied last.                                                            | 644                          |
| /etc/lynis/custom.prf                                   | Lynis profile for this workstation.                                                              | 644                          |
| /etc/security/pwquality.conf                            | Password quality.                                                                                | written by redirection       |
| /etc/security/faillock.conf                             | Account lockout.                                                                                 | written by redirection       |
| /etc/audit/rules.d/00-high-fortress-user.rules          | Audit watches.                                                                                   | 640                          |
