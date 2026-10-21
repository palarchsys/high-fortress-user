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
| /opt/high-fortress-user/bin/rkhunter-refresh-db.sh      | Rebuilds the rkhunter property baseline.                                                         | 755                          |
| /opt/high-fortress-user/bin/chkrootkit-ignore-log.sh    | Records recognized chkrootkit lines.                                                             | 755                          |
| /opt/high-fortress-user/bin/debsums-ignore-log.sh       | Records recognized debsums lines.                                                                | 755                          |
| /opt/high-fortress-user/cron/bin/*.sh                   | Watch scripts, mail.sh, and shared watchdog.sh. Owner root.                                      | 750                          |
| /opt/high-fortress-user/cron/bin/mail.html              | Mail template.                                                                                   | 644                          |
| /opt/high-fortress-user/src/config/chkrootkit/patterns.ignore | Shipped chkrootkit patterns.                                                                     | 664                          |
| /opt/high-fortress-user/cron/mail.conf                  | HF_MAIL_ALERTS, HF_WATCHDOG_MAIL, HF_PROJECT_NAME, HF_MAIL_TEMPLATE.                                      | 600                          |
| /opt/high-fortress-user/cron/rkhunter-mirrors.sha256    | Stamp of mirrors.dat after a successful update.                                                  | 600                          |
| /etc/cron.d/high-fortress-user                          | SHELL and PATH only.                                                                             | 600                          |
| /etc/systemd/system/hfu-boot-scan.service               | Boot scan unit.                                                                                  | 644                          |
| /etc/systemd/system/hfu-boot-chain.service              | Runs the boot scan, then the idle scan, then the reboot notice.                                 | 644                          |
| /etc/systemd/system/hfu-boot-chain.timer                | Starts the chain when multi-user.target is reached.                                             | 644                          |
| /etc/systemd/system/hfu-idle-scan.service               | Idle scan of the excluded paths.                                                                 | 644                          |
| /etc/systemd/system/hfu-idle-scan.timer                 | Repeats that scan every hour after the chain.                                                   | 644                          |
| /etc/systemd/system/hfu-reboot-notice.service           | Notice when a reboot is useful. The script does not reboot.                                     | 644                          |
| /etc/systemd/system/hfu-reboot-notice.timer             | Repeats that notice every 6 hours after the chain.                                              | 644                          |
| /etc/systemd/system/hfu-periodic-scan.service           | ClamAV walk every 2 hours. Same CPU and I/O limits as the boot scan.                            | 644                          |
| /etc/systemd/system/hfu-periodic-scan.timer             | Starts that walk 2 hours after boot, then every 2 hours.                                        | 644                          |
| /opt/high-fortress-user/cron/integrity.sha256           | Hash stamp written by integrity.sh during the boot scan.                                        | 600                          |
| /opt/high-fortress-user/cron/behavior.stamp             | Audit window stamp written by behavior.sh during the boot scan.                                 | 600                          |
| /opt/high-fortress-user/cron/egress.stamp               | Outbound window stamp written by egress-watch.sh during the boot scan.                          | 600                          |
| /opt/high-fortress-user/cron/bin/clamav-response.sh     | Quarantine, process signal, and short isolation after a detection.                              | 750                          |
| /opt/high-fortress-user/src/service/apparmor/detect-and-apply.sh | Loads an hfu profile only when the program exists.                               | 755                          |
| /opt/high-fortress-user/bin/scan-skip.sh                | Lists, adds or removes an excluded path, then restarts ClamAV when the block changes.            | 755                          |
| /opt/high-fortress-user/bin/boot-check.sh               | Checks that the boot security services finished this session.                                    | 755                          |
| /opt/high-fortress-user/src/config/clamav/scan-skip.paths | Excluded paths. The template is filled only when the file is still absent.                       | 644                          |
| /opt/high-fortress-user/cron/scan-skip.stamp            | Mtime watermark of the idle scan.                                                                | 644                          |
| /opt/high-fortress-user/cron/scan-skip.seen             | Signature and path pairs already mailed by the idle scan.                                        | 600                          |
| /opt/high-fortress-user/cron/reboot-notice.seen         | Digest of the last mailed reboot set.                                                                     | 600                          |
| /var/jeux                                                   | Empty directory for a game library. Not a separate account.                                      | 750                          |
| /etc/ssh/sshd_config.d/00-high-fortress-user.conf       | SSH policy for this workstation.                                                                 | 644                          |
| /etc/ssh/sshd_banner                                    | Login banner.                                                                                    | 644                          |
| /etc/aide/aide.conf                                     | AIDE policy with HF_CONFIG_BASE_DIRECTORY substituted.                                                    | written by redirection       |
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
| /etc/apt/apt.conf.d/51high-fortress-user                | Unattended upgrades, reboot off.                                                                 | written by redirection       |
| /etc/sysctl.d/90-high-fortress-user.conf                | Workstation sysctl.                                                                              | 644                          |
| /etc/sysctl.d/99-zzz-high-fortress-user.conf            | Copy of the sysctl file applied last.                                                            | 644                          |
| /etc/lynis/custom.prf                                   | Lynis profile for this workstation.                                                              | 644                          |
| /etc/security/pwquality.conf                            | Password quality.                                                                                | written by redirection       |
| /etc/security/faillock.conf                             | Account lockout.                                                                                 | written by redirection       |
| /etc/audit/rules.d/00-high-fortress-user.rules          | Audit watches.                                                                                   | 640                          |
| /etc/sudoers.d/high-fortress-user-timeout               | sudo asks for the password again after 5 minutes.                                                         | 440                          |
| /etc/usbguard/rules.conf                                | Present devices, keyboards, mice and hubs.                                                                 | 600                          |
| /etc/usbguard/IPCAccessControl.d/<user>                 | Lets the desktop user accept a new device.                                                                 | 600                          |
