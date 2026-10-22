[Vollständiges README](README.md)

# Architektur

Dies ist der Baum, der nach der Installation unter `/opt/high-fortress-user` entsteht. Es ist nicht der Klonbaum. `install.sh` entpackt das Archiv nach `src/`. `service/chkrootkit/install.sh` schreibt dort `src/config/chkrootkit/patterns.ignore`.

```
/opt/high-fortress-user/                         755
/opt/high-fortress-user/secrets/                  700
/opt/high-fortress-user/src/                      755
/opt/high-fortress-user/bin/aide-refresh-db.sh    755
/opt/high-fortress-user/bin/rkhunter-refresh-db.sh 755
/opt/high-fortress-user/bin/chkrootkit-ignore-log.sh  755
/opt/high-fortress-user/bin/debsums-ignore-log.sh 755
/opt/high-fortress-user/bin/scan-skip.sh          755
/opt/high-fortress-user/src/config/clamav/scan-skip.paths  644
/opt/high-fortress-user/src/config/chkrootkit/patterns.ignore  664
/opt/high-fortress-user/cron/scan-skip.stamp      644
/opt/high-fortress-user/cron/scan-skip.seen       600
/opt/high-fortress-user/cron/reboot-notice.seen       600
/var/jeux                                         750
/opt/high-fortress-user/cron/bin/                 755
/opt/high-fortress-user/cron/security_logs/       750
/opt/high-fortress-user/cron/alerts/              750
/opt/high-fortress-user/cron/cron_logs/           750
/opt/high-fortress-user/cron/mail.conf            600
/opt/high-fortress-user/cron/rkhunter-mirrors.sha256  600
/opt/high-fortress-user/cron/chkrootkit.local.ignore
/opt/high-fortress-user/cron/debsums.local.ignore
```

`secrets.conf` und `global.conf` bleiben in `config/` unter dem Quellverzeichnis. `HF_SECRET_DIRECTORY` wird ohne diese beiden Dateien angelegt. Nach `cron/bin` kopierte Shell-Skripte haben Modus `750`. `mail.html` hat Modus `644`. `src/config/chkrootkit/patterns.ignore` behält den Modus der mitgelieferten Datei, `664`.

Skripte in `cron/bin`: `aide.sh`, `apply-scan-skip.sh`, `behavior.sh`, `boot-scan.sh`, `chkrootkit.sh`, `clamav.sh`, `clamav-event.sh`, `clamav-response.sh`, `common.sh`, `debsums.sh`, `egress-watch.sh`, `hourly-scan.sh`, `idle-scan.sh`, `integrity.sh`, `record-mirrors.sh`, `reboot-notice.sh`, `rkhunter.sh`, `scan-skip-lib.sh`, `send.sh`, `watchdog.sh`, `mail.sh`.
