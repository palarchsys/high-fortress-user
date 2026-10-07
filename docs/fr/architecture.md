[README complet](README.md)

# Architecture

Ceci est l'arbre créé sous `/opt/high-fortress-user` après l'installation. Ce n'est pas l'arbre du clone. `src/` existe seulement lorsque `install.sh` y a extrait l'archive.

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

`secrets.conf` et `global.conf` restent dans `config/`, sous le répertoire des sources. `SECRETS_DIR` est créé sans ces deux fichiers. Les scripts shell copiés dans `cron/bin` sont en mode `750`. `mail.html` est en mode `644`. `cron/bin/chkrootkit.ignore` garde le mode du fichier livré, `664`.

Scripts dans `cron/bin` : `aide.sh`, `boot-scan.sh`, `chkrootkit.sh`, `clamav.sh`, `clamav-event.sh`, `common.sh`, `debsums.sh`, `record-mirrors.sh`, `rkhunter.sh`, `send.sh`, `mail.sh`.
