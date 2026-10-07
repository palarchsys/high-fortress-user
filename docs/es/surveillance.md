[README completo](README.md)

# Vigilancia

## AIDE

| Servicio que vigila     | Zonas                                               | Qué sale en alerta                                                   | Orden del correo                                           |
| ----------------------- | --------------------------------------------------- | -------------------------------------------------------------------- | ---------------------------------------------------------- |
| aide.sh in boot-scan.sh | /etc/aide/aide.conf, database /var/lib/aide/aide.db | Cambios, o un código distinto de cero que no es un resultado limpio. | `sudo bash /opt/high-fortress-user/bin/aide-refresh-db.sh` |

Las rutas volátiles, los diarios, las cachés y los directorios de informes cron están excluidos en `service/aide/aide.conf` para que la base no sea reescrita por esos archivos.

## rkhunter

| Servicio que vigila         | Zonas                                            | Qué sale en alerta                                                                 | Orden del correo     |
| --------------------------- | ------------------------------------------------ | ---------------------------------------------------------------------------------- | -------------------- |
| rkhunter.sh in boot-scan.sh | Alcance del paquete, más la base de propiedades. | Avisos, una actualización fallida, o `mirrors.dat modifié hors rkhunter --update`. | Sin bloque de orden. |

`/var/lib/rkhunter/db/mirrors.dat` no se ignora como archivo. La huella `/opt/high-fortress-user/cron/rkhunter-mirrors.sha256` se escribe solo después de un `rkhunter --update` que devuelve 0 o 2. Un hash distinto es una alerta. El control ocurre antes del `--update` siguiente.

## chkrootkit

| Servicio que vigila           | Zonas                   | Qué sale en alerta                                            | Orden del correo                                                             |
| ----------------------------- | ----------------------- | ------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| chkrootkit.sh in boot-scan.sh | /usr/sbin/chkrootkit -q | Cualquier salida restante después de las listas de exclusión. | `sudo bash /opt/high-fortress-user/bin/chkrootkit-ignore-log.sh '<journal>'` |

Las líneas conocidas están en `cron/bin/chkrootkit.ignore` y en `cron/chkrootkit.local.ignore`. El archivo local se llena solo con la orden del correo, y solo para líneas que usted reconoce.

## ClamAV al acceso

| Servicio que vigila             | Zonas                   | Qué sale en alerta                           | Orden del correo                   |
| ------------------------------- | ----------------------- | -------------------------------------------- | ---------------------------------- |
| clamonacc, then clamav-event.sh | Descargas y Escritorio. | Una detección real. Los cerrojos no alertan. | `sudo ls -la -- <quarantine path>` |

Excluido: `$HOME/.steam`, `$HOME/.local/share/Steam`, el usuario `clamav`, root (`OnAccessExcludeRootUID yes`) y los archivos de más de 25M. `.clamav-quarantine-lock.*` es un cerrojo de desplazamiento, no un programa dañino, así que `clamav-event.sh` sale con 0 antes de `log_alert`.

## Análisis ClamAV al arranque

| Servicio que vigila       | Zonas             | Qué sale en alerta                                     | Orden del correo     |
| ------------------------- | ----------------- | ------------------------------------------------------ | -------------------- |
| clamav.sh in boot-scan.sh | /home, /opt, /tmp | Infecciones. Un análisis limpio permanece en silencio. | Sin bloque de orden. |

El análisis poda los directorios del acceso y los nombres `BraveSoftware`, `.config/discord`, `.thunderbird`, `thunderbird`, `libvirt` y `snap-private-tmp`, para no analizar esos árboles dos veces.

## debsums

| Servicio que vigila        | Zonas                                       | Qué sale en alerta                                                       | Orden del correo                                                          |
| -------------------------- | ------------------------------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------- |
| debsums.sh in boot-scan.sh | Archivos de los paquetes, con `debsums -s`. | Archivos de paquetes modificados que no están en una lista de exclusión. | `sudo bash /opt/high-fortress-user/bin/debsums-ignore-log.sh '<journal>'` |

La línea mirrors.dat se retira solo cuando el hash actual coincide con la huella. No hay un archivo de ignorancia global para esa ruta.

## auditd

| Servicio que vigila | Zonas                                          | Qué sale en alerta                                                   | Orden del correo |
| ------------------- | ---------------------------------------------- | -------------------------------------------------------------------- | ---------------- |
| auditd              | /etc/audit/rules.d/00-high-fortress-user.rules | Sin correo propio. La pasada de arranque no envía una alerta auditd. | Ninguna.         |

## Fail2Ban

| Servicio que vigila | Zonas                    | Qué sale en alerta | Orden del correo |
| ------------------- | ------------------------ | ------------------ | ---------------- |
| fail2ban            | /etc/fail2ban/jail.local | Sin correo propio. | Ninguna.         |

## CrowdSec

| Servicio que vigila | Zonas          | Qué sale en alerta | Orden del correo |
| ------------------- | -------------- | ------------------ | ---------------- |
| crowdsec            | /etc/crowdsec/ | Sin correo propio. | Ninguna.         |

## UFW

| Servicio que vigila | Zonas                                                                                | Qué sale en alerta | Orden del correo |
| ------------------- | ------------------------------------------------------------------------------------ | ------------------ | ---------------- |
| ufw                 | Entrada denegada, salida permitida, encaminamiento permitido, bucle local permitido. | Sin correo propio. | Ninguna.         |

## Lynis

| Servicio que vigila                | Zonas                     | Qué sale en alerta                                                              | Orden del correo |
| ---------------------------------- | ------------------------- | ------------------------------------------------------------------------------- | ---------------- |
| verify/workstation.sh and hf lynis | /var/log/lynis-report.dat | Una puntuación bajo 80 es un aviso en el informe de verificación, no un correo. | Ninguna.         |
