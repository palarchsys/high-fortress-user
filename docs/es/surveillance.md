[README completo](README.md)

# Vigilancia

Una línea de diario en un correo de alerta permanece en una sola línea.

El correo de alerta mide 450px de ancho.

Una línea larga del diario se desplaza dentro del bloque de diario.

## AIDE

| Servicio que vigila     | Zonas                                               | Qué sale en alerta                                                   | Orden del correo                                           |
| ----------------------- | --------------------------------------------------- | -------------------------------------------------------------------- | ---------------------------------------------------------- |
| aide.sh in boot-scan.sh | /etc/aide/aide.conf, database /var/lib/aide/aide.db | Cambios, o un código distinto de cero que no es un resultado limpio. | `sudo bash /opt/high-fortress-user/bin/aide-refresh-db.sh` |

Las rutas volátiles, los diarios, las cachés y los directorios de informes cron están excluidos en `config/aide/aide.conf` para que la base no sea reescrita por esos archivos.

El archivo `/etc/crowdsec/hub/.index.json` está excluido.

Es el catálogo que descarga `cscli hub update`.

Los demás archivos bajo `/etc/crowdsec/` se vigilan.

El bloque de la cuenta se añade después de `!/home/`.

La última regla que coincide es la que vale.

Las rutas vigiladas son `.ssh/authorized_keys`, `.bashrc`, `.profile`, `.bash_profile`, `.config/autostart` y `.config/systemd/user` de la cuenta del puesto.

`.ssh/known_hosts` y `.ssh/known_hosts.old` quedan excluidos.

## rkhunter

| Servicio que vigila         | Zonas                                            | Qué sale en alerta                                                                 | Orden del correo     |
| --------------------------- | ------------------------------------------------ | ---------------------------------------------------------------------------------- | -------------------- |
| rkhunter.sh in boot-scan.sh | Alcance del paquete, más la base de propiedades. | Avisos, una actualización fallida, o `mirrors.dat modifié hors rkhunter --update`. | `sudo bash /opt/high-fortress-user/bin/rkhunter-refresh-db.sh` |

La orden de recálculo va en el correo de avisos cuando ningún archivo confirmado fue movido. La línea de huella y un fallo de actualización no la añaden.

`/var/lib/rkhunter/db/mirrors.dat` no se ignora como archivo. La huella `/opt/high-fortress-user/cron/rkhunter-mirrors.sha256` se escribe solo después de un `rkhunter --update` que devuelve 0 o 2. Un hash distinto es una alerta. El control ocurre antes del `--update` siguiente.

Los archivos de `/dev/shm` y el socket `/dev/log` están permitidos.

No producen el aviso `Suspicious file types found in /dev`.

Una línea restante que contiene `INFECTED`, o `Rootkit` y una ruta absoluta de archivo regular, es una detección confirmada.

Una línea que contiene `Rootkit Hunter` se omite, salvo que también contenga `INFECTED`.

Ese archivo va a `/var/lib/clamav/quarantine`.

Un titular que no está protegido recibe `TERM`.

Los titulares protegidos son el pid 1, el uid 0, un nombre vacío, `systemd`, `sshd`, `unbound`, `fail2ban` y `gamescope`.

La misma regla cubre `/etc/passwd`, `/etc/shadow`, `/etc/sudoers`, `/etc/ssh/sshd_config`, `/etc/ufw/ufw.conf`, `/usr/bin/sudo`, `/usr/bin/passwd` y `/usr/sbin/sshd`.

Una ruta o un titular protegido permanece en su sitio.

El correo dice `non mis en quarantaine`.

Cada archivo movido añade una orden de restauración.

```bash
sudo bash /opt/high-fortress-user/bin/quarantine-restore.sh <id>
```

El registro es `/opt/high-fortress-user/cron/quarantine.registry`.

La línea de éxito es `fichier remis en place`.

Un aviso que no está confirmado permanece como correo.

## chkrootkit

| Servicio que vigila           | Zonas                   | Qué sale en alerta                                            | Orden del correo                                                             |
| ----------------------------- | ----------------------- | ------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| chkrootkit.sh in boot-scan.sh | /usr/sbin/chkrootkit -q | Cualquier salida restante después de las listas de exclusión. | `sudo bash /opt/high-fortress-user/bin/chkrootkit-ignore-log.sh '<journal>'` |

Las líneas conocidas están en `src/config/chkrootkit/patterns.ignore` y en `cron/chkrootkit.local.ignore`.

El archivo local se llena solo con la orden del correo, y solo para líneas que usted reconoce.

Una detección confirmada usa el mismo desplazamiento y la misma regla `TERM` que rkhunter.

La orden de registro se adjunta solo cuando ningún archivo confirmado fue movido.

## ClamAV al acceso

| Servicio que vigila             | Zonas                   | Qué sale en alerta                           | Orden del correo                   |
| ------------------------------- | ----------------------- | -------------------------------------------- | ---------------------------------- |
| clamonacc, then clamav-event.sh | Carpetas XDG, /tmp, /var/tmp, /opt. | Una detección real. Los cerrojos no alertan. | `sudo bash /opt/high-fortress-user/bin/quarantine-restore.sh <id>` |

| Exclusión | Regla |
| --- | --- |
| `scan-skip.paths` | Solo rutas aceptadas. |
| usuario `clamav` | `OnAccessExcludeUname clamav` |
| root | `OnAccessExcludeRootUID yes` |
| tamaño | Archivos de más de 25M. |
| /var/lib/snapd, /snap | Exclusión fija. |
| /var/lib/clamav/quarantine, /var/lib/clamav/tmp | Exclusión fija. |
| /opt/high-fortress-user, /var/log | Exclusión fija. |

El archivo entregado lista:

- `$HOME/.cache`
- `$HOME/snap`
- `/var/jeux`

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

`clamav-event.sh` sale con 0 antes de `hf_log_alert`.

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
| clamav.sh in boot-scan.sh | /home, /opt, /tmp | Infecciones. Un análisis limpio permanece en silencio. | `sudo bash /opt/high-fortress-user/bin/quarantine-restore.sh <id>` |

El análisis poda las entradas `OnAccessExcludePath` y las rutas aceptadas de `scan-skip.paths`.

El análisis poda también `proc`, `sys`, `dev`, `var/lib/docker`, `var/lib/libvirt`, `libvirt` y `snap-private-tmp`.

Los archivos de más de 25M quedan fuera.

La lista de archivos se escribe bajo `/run/high-fortress-user`.

Cuando existe `/run/clamav/clamd.ctl`, la pasada pone `HF_CLAM_MODE=daemon`.

Si no, usa `clamscan`.

La unidad limita esta pasada al 50 % de la máquina.

El número se escribe al configurar cron.

Un cambio posterior del número de CPU exige repetir ese paso.

`hfu-boot-chain.service` lanza esta pasada, luego el análisis diferido, luego el aviso de reinicio.

La cadena arranca cuando `multi-user.target` está alcanzado.

Un fallo de una pasada no detiene la siguiente.

Un archivo ilegible, sin línea `FOUND`, no envía correo.

Un proceso `clamscan` detenido por una señal envía correo.

El correo nombra la señal y cada archivo no leído.

Los demás archivos de la pasada se analizan.

Dos fallos seguidos detienen la pasada de ClamAV.

El correo dice entonces que los archivos restantes no se leyeron.

## Análisis ClamAV periódico

| Servicio que vigila | Zonas | Qué sale en alerta | Orden del correo |
| --- | --- | --- | --- |
| clamav.sh en hfu-periodic-scan.timer | /home, /opt, /tmp, con las mismas podas que la pasada de arranque. | Infecciones. Una pasada limpia permanece en silencio. | `sudo bash /opt/high-fortress-user/bin/quarantine-restore.sh <id>` |

El temporizador es `OnBootSec=2h` y `OnUnitActiveSec=2h`, con `Persistent=false`.

`Nice` vale 19, `IOSchedulingClass` vale `idle`, y `CPUQuota` es la misma cuota que la pasada de arranque.

Un `lutris`, `heroic` o `gamescope` en marcha omite la pasada.

`/run/high-fortress-user/clamav.lock` impide que arranque una segunda pasada.

## Pasada horaria

| Servicio que vigila | Zonas | Qué sale en alerta | Orden del correo |
| --- | --- | --- | --- |
| hourly-scan.sh en hfu-hourly-scan.timer | AIDE, luego rkhunter, luego chkrootkit, luego debsums. Los mismos controles que la pasada de arranque. | Los mismos hallazgos que cada uno de esos controles de arranque. Una pasada limpia permanece en silencio. | La orden del correo de ese control. |

El temporizador es `OnBootSec=1h` y `OnUnitActiveSec=1h`, con `Persistent=false`.

`Nice` vale 19, `IOSchedulingClass` vale `idle`, y `CPUQuota` es la misma cuota que la pasada de arranque.

La pasada de arranque lanza estos cuatro controles.

## Análisis ClamAV diferido

| Servicio que vigila                  | Zonas                                                                                                         | Qué se alerta                                                                                                                    | Orden del correo         |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| idle-scan.sh in hfu-idle-scan.timer | Rutas aceptadas, salvo `.cache` y `snap`. | Una infección nueva. Un par ya guardado en `scan-skip.seen` no vuelve a enviar correo. | `sudo bash /opt/high-fortress-user/bin/quarantine-restore.sh <id>` |

| Ajuste | Valor |
| --- | --- |
| temporizador | `OnUnitActiveSec=1h`, `Persistent=false` |
| límites | `Nice` 19, `IOSchedulingClass=idle`, `CPUQuota` 50 % de la máquina |
| espera | `lutris`, `heroic`, `gamescope` |
| directorios saltados | `shadercache`, `downloading` |
| archivos | ejecutables de cualquier tamaño, y los demás archivos de 25M o menos más recientes que `scan-skip.stamp` |
| sello | avanza solo tras una pasada limpia |
| cubiertas | `/var/jeux` |
| no cubiertas | `$HOME/.cache`, `$HOME/snap` |

Una infección nueva llama a `clamav-response.sh`.

El archivo se mueve a `/var/lib/clamav/quarantine`. Un titular recibe TERM. El pid 1, el uid 0, un nombre vacío y los nombres systemd, sshd, unbound, fail2ban y gamescope quedan. Los flujos salientes nuevos se aíslan durante 120 segundos.

Un par conocido de firma y ruta no llama a esa respuesta.

Un proceso `clamscan` detenido por una señal envía correo.

El correo nombra la señal y cada archivo no leído.

Los demás archivos de la pasada se analizan.

Dos fallos seguidos detienen la pasada de ClamAV.

El correo dice entonces que los archivos restantes no se leyeron.

El sello permanece en su sitio.

## debsums

| Servicio que vigila        | Zonas                                       | Qué sale en alerta                                                       | Orden del correo                                                          |
| -------------------------- | ------------------------------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------- |
| debsums.sh in boot-scan.sh | Archivos de los paquetes, con `debsums -s`. | Cada paquete que queda se reinstala. El correo nombra la corrección. | Sin bloque de orden. |

La línea mirrors.dat se retira solo cuando el hash actual coincide con la huella. No hay un archivo de ignorancia global para esa ruta.

Una línea modificada bajo `/usr/lib/*/perl-base/unicore/` del paquete `perl-base` se retira antes de esta reinstalación.

## auditd

| Servicio que vigila | Zonas                                          | Qué sale en alerta                                                   | Orden del correo |
| ------------------- | ---------------------------------------------- | -------------------------------------------------------------------- | ---------------- |
| auditd              | /etc/audit/rules.d/00-high-fortress-user.rules | Sin correo propio. behavior.sh en la pasada de arranque envía el correo de un exec-tmp. | Ninguna.         |

Una vigilancia con la clave `account` se añade para `.ssh/authorized_keys`, `.bashrc`, `.profile`, `.bash_profile`, `.config/autostart` y `.config/systemd/user` cuando esa ruta ya existe.

Una ruta ausente se omite, así `augenrules` sigue cargando las reglas.

`tail.rules` registra el attach de ptrace, la carga y la retirada de módulos, y `execve` bajo `/tmp`, `/var/tmp` y `/dev/shm`.

## Fail2Ban

| Servicio que vigila | Zonas                    | Qué sale en alerta | Orden del correo |
| ------------------- | ------------------------ | ------------------ | ---------------- |
| fail2ban            | /etc/fail2ban/jail.local | Sin correo propio. | Ninguna.         |

## CrowdSec

| Servicio que vigila | Zonas          | Qué sale en alerta | Orden del correo |
| ------------------- | -------------- | ------------------ | ---------------- |
| crowdsec            | /etc/crowdsec/ | Sin correo propio. | Ninguna.         |

La duración del bloqueo es `HFU_CROWDSEC_BAN_DURATION`, por defecto `48h`.

Un nombre de `config/crowdsec/optional.list` se instala solo si el hub lo acepta.

## UFW

| Servicio que vigila | Zonas                                                                                | Qué sale en alerta | Orden del correo |
| ------------------- | ------------------------------------------------------------------------------------ | ------------------ | ---------------- |
| ufw                 | Entrada denegada, salida permitida, encaminamiento permitido, bucle local permitido. SSH queda limitado a los prefijos directamente conectados. | Sin correo propio. | Ninguna.         |

## Integridad

| Servicio que vigila | Zonas | Qué sale en alerta | Orden del correo |
| --- | --- | --- | --- |
| integrity.sh en boot-scan.sh | `config/integrity/paths.list` | Un cambio de huella. La primera pasada escribe el sello y permanece en silencio. | Sin bloque de orden. |

La pasada sigue a aide.sh.

El sello es `/opt/high-fortress-user/cron/integrity.sha256`.

## Comportamiento

| Servicio que vigila | Zonas | Qué sale en alerta | Orden del correo |
| --- | --- | --- | --- |
| behavior.sh en boot-scan.sh | `execve` bajo `/tmp`, `/var/tmp` y `/dev/shm`. | Un evento desde el sello anterior. La primera pasada escribe el sello y permanece en silencio. | Sin bloque de orden. |

La pasada sigue a rkhunter.sh.

auditd sigue en servicio.

El sello es `/opt/high-fortress-user/cron/behavior.stamp`.

## Diario saliente

| Servicio que vigila | Zonas | Qué sale en alerta | Orden del correo |
| --- | --- | --- | --- |
| tabla nftables `inet hfu_egress`, luego egress-watch.sh en boot-scan.sh | Flujos salientes nuevos fuera de los puertos 53, 80 y 443. | Una línea del núcleo con prefijo `hfu-egress` desde el sello anterior. La primera pasada escribe el sello y permanece en silencio. | Sin bloque de orden. |

La tabla se instala con política accept.

La pasada sigue a debsums.sh.

El sello es `/opt/high-fortress-user/cron/egress.stamp`.

Este control no aísla la red.

A la línea del núcleo le siguen el proceso, el pid y el uid.

La clave de audit es `hfu-egress`.

La política de la tabla permanece accept.

La salida permanece allow.

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

Un `lutris`, `heroic` o `gamescope` en marcha omite el correo.

Esa pasada deja `reboot-notice.seen` sin cambios.

El script no reinicia la máquina.

La línea de resumen es `Un redémarrage est utile. La machine n'a pas été redémarrée.`
