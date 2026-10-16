[README completo](README.md)

# Arquitectura

Este es el árbol creado bajo `/opt/high-fortress-user` después de la instalación. No es el árbol del clon. `install.sh` extrae el archivo en `src/`. `service/chkrootkit/install.sh` escribe allí `src/config/chkrootkit/chkrootkit.ignore`.

```
/opt/high-fortress-user/                         755
/opt/high-fortress-user/secrets/                  700
/opt/high-fortress-user/src/                      755
/opt/high-fortress-user/bin/aide-refresh-db.sh    755
/opt/high-fortress-user/bin/chkrootkit-ignore-log.sh  755
/opt/high-fortress-user/bin/debsums-ignore-log.sh 755
/opt/high-fortress-user/bin/scan-skip.sh          755
/opt/high-fortress-user/src/config/clamav/scan-skip.paths  644
/opt/high-fortress-user/src/config/chkrootkit/chkrootkit.ignore  664
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

`secrets.conf` y `global.conf` permanecen en `config/`, bajo el directorio de las fuentes. `HF_SECRET_DIRECTORY` se crea sin esos dos archivos. Los scripts shell copiados a `cron/bin` están en modo `750`. `mail.html` está en modo `644`. `src/config/chkrootkit/chkrootkit.ignore` conserva el modo del archivo entregado, `664`.

Scripts en `cron/bin`: `aide.sh`, `apply-scan-skip.sh`, `boot-scan.sh`, `chkrootkit.sh`, `clamav.sh`, `clamav-event.sh`, `common.sh`, `debsums.sh`, `idle-scan.sh`, `record-mirrors.sh`, `reboot-notice.sh`, `rkhunter.sh`, `scan-skip-lib.sh`, `send.sh`, `watchdog.sh`, `mail.sh`.
