[README completo](README.md)

# Arquitectura

Este es el árbol creado bajo `/opt/high-fortress-user` después de la instalación. No es el árbol del clon. `src/` existe solo cuando `install.sh` extrajo el archivo allí.

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

`secrets.conf` y `global.conf` permanecen en `config/`, bajo el directorio de las fuentes. `SECRETS_DIR` se crea sin esos dos archivos. Los scripts shell copiados a `cron/bin` están en modo `750`. `mail.html` está en modo `644`. `cron/bin/chkrootkit.ignore` conserva el modo del archivo entregado, `664`.

Scripts en `cron/bin`: `aide.sh`, `boot-scan.sh`, `chkrootkit.sh`, `clamav.sh`, `clamav-event.sh`, `common.sh`, `debsums.sh`, `record-mirrors.sh`, `rkhunter.sh`, `send.sh`, `mail.sh`.
