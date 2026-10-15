[README completo](README.md)

# Vigilancia

## AIDE

| Servicio que vigila     | Zonas                                               | Qué sale en alerta                                                   | Orden del correo                                           |
| ----------------------- | --------------------------------------------------- | -------------------------------------------------------------------- | ---------------------------------------------------------- |
| aide.sh in boot-scan.sh | /etc/aide/aide.conf, database /var/lib/aide/aide.db | Cambios, o un código distinto de cero que no es un resultado limpio. | `sudo bash /opt/high-fortress-user/bin/aide-refresh-db.sh` |

Las rutas volátiles, los diarios, las cachés y los directorios de informes cron están excluidos en `service/aide/aide.conf` para que la base no sea reescrita por esos archivos.

El bloque de la cuenta se añade después de `!/home/`.

La última regla que coincide es la que vale.

Las rutas vigiladas son `.ssh/authorized_keys`, `.bashrc`, `.profile`, `.bash_profile`, `.config/autostart` y `.config/systemd/user` de la cuenta del puesto.

`.ssh/known_hosts` y `.ssh/known_hosts.old` quedan excluidos.

## rkhunter

| Servicio que vigila         | Zonas                                            | Qué sale en alerta                                                                 | Orden del correo     |
| --------------------------- | ------------------------------------------------ | ---------------------------------------------------------------------------------- | -------------------- |
| rkhunter.sh in boot-scan.sh | Alcance del paquete, más la base de propiedades. | Avisos, una actualización fallida, o `mirrors.dat modifié hors rkhunter --update`. | Sin bloque de orden. |

`/var/lib/rkhunter/db/mirrors.dat` no se ignora como archivo. La huella `/opt/high-fortress-user/cron/rkhunter-mirrors.sha256` se escribe solo después de un `rkhunter --update` que devuelve 0 o 2. Un hash distinto es una alerta. El control ocurre antes del `--update` siguiente.

Los archivos de `/dev/shm` y el socket `/dev/log` están permitidos.

No producen el aviso `Suspicious file types found in /dev`.

## chkrootkit

| Servicio que vigila           | Zonas                   | Qué sale en alerta                                            | Orden del correo                                                             |
| ----------------------------- | ----------------------- | ------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| chkrootkit.sh in boot-scan.sh | /usr/sbin/chkrootkit -q | Cualquier salida restante después de las listas de exclusión. | `sudo bash /opt/high-fortress-user/bin/chkrootkit-ignore-log.sh '<journal>'` |

Las líneas conocidas están en `cron/bin/chkrootkit.ignore` y en `cron/chkrootkit.local.ignore`. El archivo local se llena solo con la orden del correo, y solo para líneas que usted reconoce.

## ClamAV al acceso

| Servicio que vigila             | Zonas                   | Qué sale en alerta                           | Orden del correo                   |
| ------------------------------- | ----------------------- | -------------------------------------------- | ---------------------------------- |
| clamonacc, then clamav-event.sh | Descargas y Escritorio. | Una detección real. Los cerrojos no alertan. | `sudo ls -la -- <quarantine path>` |

| Exclusión | Regla |
| --- | --- |
| `scan-skip.paths` | Solo rutas aceptadas. |
| usuario `clamav` | `OnAccessExcludeUname clamav` |
| root | `OnAccessExcludeRootUID yes` |
| tamaño | Archivos de más de 25M. |

El archivo entregado lista:

- `$HOME/.steam`
- `$HOME/.local/share/Steam`
- `$HOME/.cache`
- `$HOME/snap`
- `/var/jeux`

Brave, Thunderbird y Discord siguen en el análisis.

Una ruta se acepta bajo el home del usuario del puesto, por debajo de ese home.

Una ruta se acepta bajo `/var/jeux`, incluido `/var/jeux`.

| Rechazo | Rutas |
| --- | --- |
| raíces del sistema | `/`, `/home`, `/opt`, `/tmp`, `/etc`, `/usr`, `/var`, `/boot`, `/root` |
| home entero | `/home/<user>` |
| directorios al acceso | Descargas, Escritorio |
| padre de esos directorios | un directorio que contiene Descargas o Escritorio |
| en otro lugar | una ruta fuera de ese home y fuera de `/var/jeux` |

Una línea rechazada se ignora.

Se añade a `/opt/high-fortress-user/cron/security_logs/scan-skip.log`.

`/var/jeux` es un directorio vacío, modo 750, propietario el usuario del puesto.

No es una cuenta distinta.

`.clamav-quarantine-lock.*` es un cerrojo de desplazamiento, no un programa dañino.

`clamav-event.sh` sale con 0 antes de `log_alert`.

`scan-skip.sh` cambia la lista.

Las órdenes están en el README.

La misma reescritura corre al inicio de `boot-scan.sh`.

Un `scan-skip.paths` ya presente no se sustituye cuando el instalador vuelve a ejecutarse.

La reescritura sustituye las líneas `OnAccessExcludePath` entre `# BEGIN High-Fortress User scan-skip` y `# END High-Fortress User scan-skip`.

La reescritura reinicia `clamav-daemon`, luego `clamav-clamonacc.service` o `clamonacc.service`, cuando ese bloque cambia.

Una ruta oculta recibe `ALLOWHIDDENDIR` en `/etc/rkhunter.conf.local` cuando falta la línea.

Las líneas rkhunter ya presentes se quedan.

## Análisis ClamAV al arranque

| Servicio que vigila       | Zonas             | Qué sale en alerta                                     | Orden del correo     |
| ------------------------- | ----------------- | ------------------------------------------------------ | -------------------- |
| clamav.sh in boot-scan.sh | /home, /opt, /tmp | Infecciones. Un análisis limpio permanece en silencio. | Sin bloque de orden. |

El análisis poda los directorios del acceso.

El análisis poda las rutas aceptadas de `scan-skip.paths`.

El análisis poda también `proc`, `sys`, `dev`, `var/lib/docker`, `var/lib/libvirt`, `libvirt` y `snap-private-tmp`.

El análisis lee los archivos con `clamscan`, en la unidad de arranque.

La unidad limita esta pasada al 50 % de la máquina.

El número se escribe al configurar cron.

Un cambio posterior del número de CPU exige repetir ese paso.

`hfu-boot-chain.service` lanza esta pasada, luego el análisis diferido, luego el aviso de reinicio.

La cadena arranca cuando `multi-user.target` está alcanzado.

Un fallo de una pasada no detiene la siguiente.

Brave, Thunderbird y Discord permanecen en esta pasada.

Un archivo ilegible, sin línea `FOUND`, no envía correo.

Un proceso `clamscan` detenido por una señal envía correo.

El correo nombra la señal y cada archivo no leído.

Los demás archivos de la pasada se analizan.

Dos fallos seguidos detienen la pasada de ClamAV.

El correo dice entonces que los archivos restantes no se leyeron.

## Análisis ClamAV diferido

| Servicio que vigila                  | Zonas                                                                                                         | Qué se alerta                                                                                                                    | Orden del correo         |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| idle-scan.sh in hfu-idle-scan.timer | Rutas aceptadas, salvo `.cache` y `snap`. | Una infección nueva. Un par ya guardado en `scan-skip.seen` no vuelve a enviar correo. | Sin bloque de orden. |

| Ajuste | Valor |
| --- | --- |
| temporizador | `OnUnitActiveSec=1h`, `Persistent=false` |
| límites | `Nice` 19, `IOSchedulingClass=idle`, `CPUQuota` 50 % de la máquina |
| espera | `steam`, `steamwebhelper`, `lutris`, `heroic`, `wineserver`, `gamescope` |
| directorios saltados | `shadercache`, `downloading` |
| archivos | ejecutables de cualquier tamaño, y los demás archivos de 25M o menos más recientes que `scan-skip.stamp` |
| sello | avanza solo tras una pasada limpia |
| cubiertas | `/var/jeux`, `$HOME/.steam`, `$HOME/.local/share/Steam` |
| no cubiertas | `$HOME/.cache`, `$HOME/snap` |

Un proceso `clamscan` detenido por una señal envía correo.

El correo nombra la señal y cada archivo no leído.

Los demás archivos de la pasada se analizan.

Dos fallos seguidos detienen la pasada de ClamAV.

El correo dice entonces que los archivos restantes no se leyeron.

El sello permanece en su sitio.

## debsums

| Servicio que vigila        | Zonas                                       | Qué sale en alerta                                                       | Orden del correo                                                          |
| -------------------------- | ------------------------------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------- |
| debsums.sh in boot-scan.sh | Archivos de los paquetes, con `debsums -s`. | Archivos de paquetes modificados que no están en una lista de exclusión. | `sudo bash /opt/high-fortress-user/bin/debsums-ignore-log.sh '<journal>'` |

La línea mirrors.dat se retira solo cuando el hash actual coincide con la huella. No hay un archivo de ignorancia global para esa ruta.

Una línea modificada bajo `/usr/lib/*/perl-base/unicore/` del paquete `perl-base` se retira antes del correo.

## auditd

| Servicio que vigila | Zonas                                          | Qué sale en alerta                                                   | Orden del correo |
| ------------------- | ---------------------------------------------- | -------------------------------------------------------------------- | ---------------- |
| auditd              | /etc/audit/rules.d/00-high-fortress-user.rules | Sin correo propio. La pasada de arranque no envía una alerta auditd. | Ninguna.         |

Una vigilancia con la clave `account` se añade para `.ssh/authorized_keys`, `.bashrc`, `.profile`, `.bash_profile`, `.config/autostart` y `.config/systemd/user` cuando esa ruta ya existe.

Una ruta ausente se omite, así `augenrules` sigue cargando las reglas.

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
| ufw                 | Entrada denegada, salida permitida, encaminamiento permitido, bucle local permitido. SSH queda limitado a los prefijos directamente conectados. | Sin correo propio. | Ninguna.         |

## Lynis

| Servicio que vigila                | Zonas                     | Qué sale en alerta                                                              | Orden del correo |
| ---------------------------------- | ------------------------- | ------------------------------------------------------------------------------- | ---------------- |
| verify/workstation.sh and hf lynis | /var/log/lynis-report.dat | Una puntuación bajo 80 es un aviso en el informe de verificación, no un correo. | Ninguna.         |

`verify/workstation.sh` informa de Secure Boot con `mokutil`.

Informa de una raíz LUKS cuando `lsblk` muestra `crypt` para el origen de la raíz.

La ausencia de uno de los dos es un aviso.

El instalador deja ambos sin cambios.

## Aviso de reinicio

| Servicio que vigila | Zonas | Qué sale en alerta | Orden del correo |
| --- | --- | --- | --- |
| reboot-notice.sh in hfu-reboot-notice.timer | `/var/run/reboot-required`, `/var/run/reboot-required.pkgs`, y `fwupdmgr get-updates` cuando esa orden termina con 0 | Un conjunto nuevo. La misma huella en `reboot-notice.seen` no vuelve a enviar correo. | Sin bloque de orden. |

El temporizador es `OnUnitActiveSec=6h`, con `Persistent=false`.

La cadena de arranque lanza este aviso después del análisis diferido.

`Nice` vale 19, `IOSchedulingClass` vale `idle`, y `CPUQuota` vale 50 % de la máquina.

Un `steam`, `steamwebhelper`, `lutris`, `heroic`, `wineserver` o `gamescope` en marcha omite el correo.

Esa pasada deja `reboot-notice.seen` sin cambios.

El script no reinicia la máquina.

La línea de resumen es `Un redémarrage est utile. La machine n'a pas été redémarrée.`
