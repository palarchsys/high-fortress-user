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

Excluido del análisis al acceso: cada ruta aceptada de `/opt/high-fortress-user/cron/scan-skip.paths`, el usuario `clamav`, root (`OnAccessExcludeRootUID yes`) y los archivos de más de 25M. El archivo entregado en la instalación lista `$HOME/.steam`, `$HOME/.local/share/Steam`, `$HOME/.cache`, `$HOME/snap` y `/var/jeux`. Brave, Thunderbird y Discord no están. Una línea relativa, vacía, o exactamente `/`, `/home`, `/opt`, `/tmp`, `/etc`, `/usr`, `/var`, `/boot`, `/root`, `/home/<user>`, Descargas o Escritorio se ignora y se añade a `/opt/high-fortress-user/cron/security_logs/scan-skip.log`. `/var/jeux` es un directorio vacío, modo 750, propietario el usuario del puesto. No es una cuenta distinta. `.clamav-quarantine-lock.*` es un cerrojo de desplazamiento, no un programa dañino, así que `clamav-event.sh` sale con 0 antes de `log_alert`.

La lista se cambia con `scan-skip.sh`. La misma reescritura corre al inicio de `boot-scan.sh`. Un `scan-skip.paths` ya presente no se sustituye cuando el instalador vuelve a ejecutarse.

```bash
sudo bash /opt/high-fortress-user/bin/scan-skip.sh list
sudo bash /opt/high-fortress-user/bin/scan-skip.sh add /var/jeux/steam
sudo bash /opt/high-fortress-user/bin/scan-skip.sh del /var/jeux/steam
```

`list` muestra una ruta aceptada por línea. `add` muestra `Chemin ajouté : <path>`. Una ruta ya presente muestra `Ce chemin est déjà exclu : <path>`. `del` muestra `Chemin retiré : <path>`. Una ruta rechazada muestra `Chemin refusé : <path>`. La orden reescribe las líneas `OnAccessExcludePath` entre `# BEGIN High-Fortress User scan-skip` y `# END High-Fortress User scan-skip` en `/etc/clamav/clamd.conf`. `clamav-daemon` solo se recarga cuando ese bloque cambia. Una ruta oculta recibe una línea `ALLOWHIDDENDIR` en `/etc/rkhunter.conf.local` cuando falta. Las líneas rkhunter ya presentes se quedan.

## Análisis ClamAV al arranque

| Servicio que vigila       | Zonas             | Qué sale en alerta                                     | Orden del correo     |
| ------------------------- | ----------------- | ------------------------------------------------------ | -------------------- |
| clamav.sh in boot-scan.sh | /home, /opt, /tmp | Infecciones. Un análisis limpio permanece en silencio. | Sin bloque de orden. |

El análisis poda los directorios del acceso y las rutas aceptadas de `scan-skip.paths`. También poda `proc`, `sys`, `dev`, `var/lib/docker`, `var/lib/libvirt`, `libvirt` y `snap-private-tmp`. Lee los archivos con `clamscan`, en la unidad de arranque. No llama a `clamdscan`. Brave, Thunderbird y Discord permanecen en esta pasada.

## Análisis ClamAV diferido

| Servicio que vigila                  | Zonas                                                                                                         | Qué se alerta                                                                                                                    | Orden del correo         |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| idle-scan.sh in hfu-idle-scan.timer  | Rutas aceptadas de `scan-skip.paths`, salvo un directorio cuyo último componente es `.cache` o `snap`.       | Una infección nueva. Una firma y una ruta ya guardadas en `/opt/high-fortress-user/cron/scan-skip.seen` no vuelven a enviar correo. | Sin bloque de orden.     |

`hfu-idle-scan.timer` usa `OnBootSec=15min`, `OnUnitActiveSec=1h` y `Persistent=true`. `Nice` vale `WATCHDOG_LIMIT_NICE` (19), `IOSchedulingClass=idle`, y `CPUQuota` vale `WATCHDOG_CPU_LIMIT` (20 %). La pasada sale con 0 sin analizar mientras `steam`, `steamwebhelper`, `lutris`, `heroic`, `wineserver` o `gamescope` está en marcha. Salta los directorios `shadercache` y `downloading`. Analiza los archivos ejecutables de cualquier tamaño, y los demás archivos de 25M o menos más recientes que `/opt/high-fortress-user/cron/scan-skip.stamp`. El sello solo avanza tras una pasada limpia. `/var/jeux`, `$HOME/.steam` y `$HOME/.local/share/Steam` están cubiertos. `$HOME/.cache` y `$HOME/snap` no.

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
