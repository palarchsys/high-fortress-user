[README complet](README.md)

# Architecture

Ceci est l'arbre créé sous `/opt/high-fortress-user` après l'installation. Ce n'est pas l'arbre du clone. `install.sh` extrait l'archive dans `src/`. `service/chkrootkit/install.sh` y écrit `src/config/chkrootkit/patterns.ignore`.

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

`secrets.conf` et `global.conf` restent dans `config/`, sous le répertoire des sources. `HF_SECRET_DIRECTORY` est créé sans ces deux fichiers. Les scripts shell copiés dans `cron/bin` sont en mode `750`. `mail.html` est en mode `644`. `src/config/chkrootkit/patterns.ignore` garde le mode du fichier livré, `664`.

Scripts dans `cron/bin` : `aide.sh`, `apply-scan-skip.sh`, `behavior.sh`, `boot-scan.sh`, `chkrootkit.sh`, `clamav.sh`, `clamav-event.sh`, `clamav-response.sh`, `common.sh`, `debsums.sh`, `egress-watch.sh`, `idle-scan.sh`, `integrity.sh`, `record-mirrors.sh`, `reboot-notice.sh`, `rkhunter.sh`, `scan-skip-lib.sh`, `send.sh`, `watchdog.sh`, `mail.sh`.
