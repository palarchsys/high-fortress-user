[Full README](README.md)

# Configuration

Names and defaults below are the shipped `user/config/global.conf` and `hfu_config_set_builtin_defaults`. Brackets in a prompt are the value Enter keeps.

## general variables

| Name                       | Default                                                          | Impact                                                                                      |
| -------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| HF_PREPARED                | 1                                                                | Must be 1 or the check refuses the files.                                                   |
| PROJECT_NAME               | High-Fortress User                                               | Shown in mail. Not asked.                                                                   |
| PROJECT_SLUG               | high-fortress-user                                               | Fixed by the check. Builds `CONFIG_BASE_DIR`.                                               |
| PROJECT_VERSION            | 0.2                                                              | Recorded. Not asked.                                                                        |
| CONFIG_BASE_DIR            | /opt/high-fortress-user                                          | Runtime root. Derived from `PROJECT_SLUG`.                                                  |
| SECRETS_DIR                | /opt/high-fortress-user/secrets                                  | Created mode 700. `secrets.conf` is not written here.                                       |
| DEBUG_INSTALL_LOGS         | 0                                                                | Present in the file. Install journals always go to `<source>/logs/`.                        |
| MODE_TEST                  | 1                                                                | Asked. `1` skips the removal question at the end. `0` asks it.                              |
| LYNIS_MIN_SCORE            | 80                                                               | Minimum accepted hardening index. Not asked.                                                |
| HFU_OS_ID                  | ubuntu                                                           | Fixed by the check.                                                                         |
| HFU_OS_VERSION             | 26.04                                                            | Fixed by the check.                                                                         |
| BANNER_MESSAGE             | text in global.conf                                              | Written to `/etc/ssh/sshd_banner`. Not asked.                                               |
| SSH_BANNER_PATH            | /etc/ssh/sshd_banner                                             | Banner file. Not asked.                                                                     |
| SSH_SERVICE_NAME           | ssh                                                              | Service name. Not asked.                                                                    |
| SSH_MAX_AUTH_TRIES         | 4                                                                | sshd `MaxAuthTries`. Not asked.                                                             |
| SSH_CLIENT_ALIVE_INTERVAL  | 300                                                              | sshd interval in seconds. Not asked.                                                        |
| SSH_CLIENT_ALIVE_COUNT_MAX | 2                                                                | sshd probe count. Not asked.                                                                |
| SSH_LOGIN_GRACE_TIME       | 30                                                               | sshd grace time in seconds. Not asked.                                                      |
| PWQUALITY_MINLEN           | 12                                                               | Minimum password length in `/etc/security/pwquality.conf`. Not asked.                       |
| FAILLOCK_DENY              | 8                                                                | Failures before lockout. Not asked.                                                         |
| FAILLOCK_UNLOCK            | 600                                                              | Lockout seconds. Not asked.                                                                 |
| FAILLOCK_FAIL_INTERVAL     | 900                                                              | Window for counting failures. Not asked.                                                    |
| WATCHDOG_CPU_LIMIT         | 20                                                               | CPU quota percent of the boot scan. Not asked.                                              |
| WATCHDOG_LIMIT_NICE        | 19                                                               | Nice value of the boot scan. Not asked.                                                     |
| WATCHDOG_LIMIT_IONICE      | 3                                                                | Ionice class number stored in the file. The timer uses `IOSchedulingClass=idle`. Not asked. |
| HF_MAIL_ALERTS             | 1 in the shipped file, 0 in the builtin default until you answer | Set from the alert answer.                                                                  |
| MAIL_TEMPLATE              | mail.html                                                        | HTML template copied to `cron/bin`. Not asked.                                              |

## secrets.conf

The file is written in `config/`, next to `global.conf`, mode `600`, owner root. It is not written into `SECRETS_DIR`. The values are not listed here.

| Name                 | Where        | Rule                                                       |
| -------------------- | ------------ | ---------------------------------------------------------- |
| UBUNTU_PRO_TOKEN     | secrets.conf | Asked. Required. Letters and digits, 6 to 100.             |
| POSTFIX_SMTP_LOGIN   | secrets.conf | Asked only when alerts are enabled.                        |
| POSTFIX_MAIL_ADDRESS | secrets.conf | From address. Also copied to `WATCHDOG_MAIL`.              |
| POSTFIX_MAIL_PASS    | secrets.conf | Application password, 8 to 128 characters, spaces removed. |
| POSTFIX_MAIL_SMTP    | secrets.conf | `host:port` without brackets.                              |
| WATCHDOG_MAIL        | secrets.conf | Same value as `POSTFIX_MAIL_ADDRESS`.                      |
| HF_SECRETS_PREPARED  | secrets.conf | Set to 1 by the writer. Not asked.                         |

## Service variables

| Name                          | Default                                   | Impact                                                               |
| ----------------------------- | ----------------------------------------- | -------------------------------------------------------------------- |
| OnAccessIncludePath           | Downloads and Desktop                     | `xdg-user-dir`, or `$HOME/Downloads` and `$HOME/Desktop`.            |
| OnAccessExcludePath           | $HOME/.steam and $HOME/.local/share/Steam | Steam data is not scanned on access.                                 |
| OnAccessExcludeUname          | clamav                                    | The scanner user is excluded.                                        |
| OnAccessExcludeRootUID        | yes                                       | Root is excluded from on-access scan on this workstation.            |
| OnAccessMaxFileSize           | 25M                                       | Larger files are not scanned on access.                              |
| OnAccessPrevention            | yes                                       | A detection is moved to quarantine.                                  |
| quarantine                    | /var/lib/clamav/quarantine                | Mode 750, owner clamav.                                              |
| hfu-boot-scan.timer OnBootSec | 2min                                      | `Persistent=false`. A machine already up waits for the next boot.    |
| database_in                   | /var/lib/aide/aide.db                     | `__HF_BASE__` in `service/aide/aide.conf` becomes `CONFIG_BASE_DIR`. |

## Docker

This workstation has no `docker/` tree. No image, tag, port, or volume is set by this installer.

## Not asked, and generated

Asked values are the Ubuntu Pro token, the alert choice, the SMTP fields when alerts are enabled, and `MODE_TEST`. Everything else in the tables is not asked. Nothing is generated with `openssl`. `HF_MAIL_ALERTS` is `1` or `0` from the answer. Empty mail fields are written when alerts are disabled.
