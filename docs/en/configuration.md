[Full README](README.md)

# Configuration

Names and defaults below are the shipped `user/config/global.conf` and `hfu_set_config_default`. Brackets in a prompt are the value Enter keeps.

## general variables

| Name                       | Default                                                          | Impact                                                                                      |
| -------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| HF_CONFIG_PREPARED                | 1                                                                | Must be 1 or the check refuses the files.                                                   |
| HF_PROJECT_NAME               | High-Fortress User                                               | Shown in mail. Not asked.                                                                   |
| HFU_PROJECT_SLUG               | high-fortress-user                                               | Fixed by the check. Names `/etc/cron.d/high-fortress-user`.                                  |
| HF_PROJECT_VERSION            | 0.2                                                              | Recorded. Not asked.                                                                        |
| HF_CONFIG_BASE_DIRECTORY            | /opt/high-fortress-user                                          | Runtime root.                                                                               |
| HF_SECRET_DIRECTORY                | /opt/high-fortress-user/secrets                                  | Created mode 700. `secrets.conf` is not written here.                                       |
| HF_DEBUG_INSTALL_LOG         | 0                                                                | Present in the file. Install journals always go to `<source>/logs/`.                        |
| HF_MODE_TEST                  | 1                                                                | Asked. `1` skips the removal question at the end. `0` asks it.                              |
| HF_LYNIS_MIN_SCORE            | 80                                                               | Minimum accepted hardening index. Not asked.                                                |
| HFU_OS_ID                  | ubuntu                                                           | Fixed by the check.                                                                         |
| HFU_OS_VERSION             | 26.04                                                            | Fixed by the check.                                                                         |
| HF_BANNER_MESSAGE             | text in global.conf                                              | Written to `/etc/ssh/sshd_banner`. Not asked.                                               |
| HF_SSH_BANNER_PATH            | /etc/ssh/sshd_banner                                             | Banner file. Not asked.                                                                     |
| HF_SSH_SERVICE_NAME           | ssh                                                              | Service name. Not asked.                                                                    |
| HF_SSH_MAX_AUTH_TRIES         | 4                                                                | sshd `MaxAuthTries`. Not asked.                                                             |
| HF_SSH_CLIENT_ALIVE_INTERVAL  | 300                                                              | sshd interval in seconds. Not asked.                                                        |
| HF_SSH_CLIENT_ALIVE_COUNT_MAX | 2                                                                | sshd probe count. Not asked.                                                                |
| HFU_SSH_LOGIN_GRACE_TIME       | 30                                                               | sshd grace time in seconds. Not asked.                                                      |
| HFU_PAM_PASSWORD_MIN_LENGTH           | 12                                                               | Minimum password length in `/etc/security/pwquality.conf`. Not asked.                       |
| HFU_FAILLOCK_DENY              | 8                                                                | Failures before lockout. Not asked.                                                         |
| HFU_FAILLOCK_UNLOCK            | 600                                                              | Lockout seconds. Not asked.                                                                 |
| HFU_FAILLOCK_FAIL_INTERVAL     | 900                                                              | Window for counting failures. Not asked.                                                    |
| HF_WATCHDOG_CPU_LIMIT         | 50                                                               | Percent of the whole machine for one pass. The unit stores `CPUQuota` as this number times the CPU count. Not asked. |
| HF_WATCHDOG_LIMIT_NICE        | 19                                                               | Nice value of the boot scan. Not asked.                                                     |
| HF_WATCHDOG_LIMIT_IO_NICE      | 3                                                                | Ionice class number stored in the file. The timer uses `IOSchedulingClass=idle`. Not asked. |
| HF_MAIL_ALERTS             | 1 in the shipped file, 0 in the builtin default until you answer | Set from the alert answer.                                                                  |
| HF_MAIL_TEMPLATE              | mail.html                                                        | HTML template copied to `cron/bin`. Not asked.                                              |

## secrets.conf

The file is written in `config/`, next to `global.conf`, mode `600`, owner root. It is not written into `HF_SECRET_DIRECTORY`. The values are not listed here.

| Name                 | Where        | Rule                                                       |
| -------------------- | ------------ | ---------------------------------------------------------- |
| HF_UBUNTU_PRO_TOKEN     | secrets.conf | Asked. Required. Letters and digits, 6 to 100.             |
| HF_POSTFIX_SMTP_LOGIN   | secrets.conf | Asked only when alerts are enabled.                        |
| HF_POSTFIX_MAIL_ADDRESS | secrets.conf | From address. Also copied to `HF_WATCHDOG_MAIL`.              |
| HF_POSTFIX_MAIL_PASSWORD    | secrets.conf | Application password, 8 to 128 characters, spaces removed. |
| HF_POSTFIX_MAIL_SMTP    | secrets.conf | `host:port` without brackets.                              |
| HF_WATCHDOG_MAIL        | secrets.conf | Same value as `HF_POSTFIX_MAIL_ADDRESS`.                      |
| HF_SECRET_PREPARED  | secrets.conf | Set to 1 by the writer. Not asked.                         |

## Service variables

| Name                          | Default                                   | Impact                                                               |
| ----------------------------- | ----------------------------------------- | -------------------------------------------------------------------- |
| OnAccessIncludePath           | XDG dirs, /tmp, /var/tmp, /opt            | Downloads, Desktop, Documents, Music, Pictures, Videos, /tmp, /var/tmp and /opt. |
| HFU_ONACCESS_MOUNTS           | 1                                         | 0 leaves /media and /mnt out.                                        |
| process signal                | always                                    | Signals one non-critical process that holds the detected file. pid 1, root, systemd, sshd, unbound, fail2ban and gamescope stay running. |
| OnAccessExcludePath           | config/clamav/scan-skip.paths             | Accepted paths under the workstation user's home, or under `/var/jeux`. |
| OnAccessExcludeUname          | clamav                                    | The scanner user is excluded.                                        |
| OnAccessExcludeRootUID        | yes                                       | Root is excluded from on-access scan on this workstation.            |
| OnAccessMaxFileSize           | 25M                                       | Larger files are not scanned on access.                              |
| OnAccessPrevention            | yes                                       | A detection is moved to quarantine.                                  |
| quarantine                    | /var/lib/clamav/quarantine                | Mode 750, owner clamav.                                              |
| hfu-boot-chain.timer          | OnBootSec=0, Persistent=false             | Starts the chain when `multi-user.target` is reached. The session does not wait. |
| hfu-idle-scan.timer           | OnUnitActiveSec=1h, Persistent=false      | Same Nice, idle I/O and CPU quota as the boot pass. No fixed delay after boot. |
| hfu-reboot-notice.timer       | OnUnitActiveSec=6h, Persistent=false      | Same quota. The script does not reboot the machine. |
| hfu-periodic-scan.timer       | OnBootSec=2h, OnUnitActiveSec=2h          | Runs clamav.sh only. Same Nice, idle I/O and CPU quota. Persistent=false. |
| integrity.sh                  | boot-scan.sh, after aide.sh           | Hashes config/integrity/paths.list. The first pass writes cron/integrity.sha256 and stays silent. |
| behavior.sh                   | boot-scan.sh, after rkhunter.sh       | Reads exec-tmp events since cron/behavior.stamp. The first pass writes the stamp and stays silent. auditd stays running. |
| inet hfu_egress               | installed                             | Logs new outbound flows outside ports 53, 80 and 443. Policy accept. Outgoing stays allow. |
| egress-watch.sh               | boot-scan.sh, after debsums.sh        | Reads kernel lines prefixed hfu-egress since cron/egress.stamp. The first pass writes the stamp and stays silent. |
| network isolation             | always                                    | After a detection, rejects new outbound flows for HFU_NET_ISOLATE_SEC. Loopback, DNS and established flows stay. Outgoing policy stays allow. |
| HFU_NET_ISOLATE_SEC           | 120                                       | Seconds before that isolation is removed. Minimum 30, maximum 300. |
| HFU_CROWDSEC_BAN_DURATION     | 48h                                       | Written into the CrowdSec profiles. |
| scan-skip.sh                  | /opt/high-fortress-user/bin/scan-skip.sh  | Restarts `clamav-daemon` and `clamonacc` when the exclude block changes. |
| database_in                   | /var/lib/aide/aide.db                     | `__HF_BASE__` in `config/aide/aide.conf` becomes `HF_CONFIG_BASE_DIRECTORY`. |

## Docker

This workstation has no `docker/` tree. No image, tag, port, or volume is set by this installer.

## Not asked, and generated

Asked values are the Ubuntu Pro token, the alert choice, the SMTP fields when alerts are enabled, and `HF_MODE_TEST`. Everything else in the tables is not asked. Nothing is generated with `openssl`. `HF_MAIL_ALERTS` is `1` or `0` from the answer. Empty mail fields are written when alerts are disabled.
