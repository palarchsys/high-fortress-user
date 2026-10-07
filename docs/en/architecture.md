[Full README](README.md)

# Architecture

This is the tree created under `/opt/high-fortress-user` after installation. It is not the clone tree. `src/` exists only when `install.sh` extracted the archive there.

```
/opt/high-fortress-user/                         755
/opt/high-fortress-user/secrets/                  700
/opt/high-fortress-user/src/                      install.sh only
/opt/high-fortress-user/bin/aide-refresh-db.sh    755
/opt/high-fortress-user/bin/chkrootkit-ignore-log.sh  755
/opt/high-fortress-user/bin/debsums-ignore-log.sh 755
/opt/high-fortress-user/cron/bin/                 755
/opt/high-fortress-user/cron/security_logs/       750
/opt/high-fortress-user/cron/alerts/              750
/opt/high-fortress-user/cron/cron_logs/           750
/opt/high-fortress-user/cron/mail.conf            600
/opt/high-fortress-user/cron/rkhunter-mirrors.sha256  600
/opt/high-fortress-user/cron/chkrootkit.local.ignore
/opt/high-fortress-user/cron/debsums.local.ignore
```

`secrets.conf` and `global.conf` stay in `config/` under the source directory. `SECRETS_DIR` is created empty of those two files. Shell scripts copied into `cron/bin` are mode `750`. `mail.html` is mode `644`. `cron/bin/chkrootkit.ignore` keeps the mode of the shipped file, `664`.

Scripts in `cron/bin`: `aide.sh`, `boot-scan.sh`, `chkrootkit.sh`, `clamav.sh`, `clamav-event.sh`, `common.sh`, `debsums.sh`, `record-mirrors.sh`, `rkhunter.sh`, `send.sh`, `mail.sh`.
