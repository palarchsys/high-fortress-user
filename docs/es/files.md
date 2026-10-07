[README completo](README.md)

# Archivos

Cada fila es un archivo que el instalador escribe, con el modo que el script fija. Los archivos internos de los paquetes Ubuntu no se listan uno por uno: el depósito no los nombra.

| Ruta                                                    | Función                                                                                                  | Permisos                     |
| ------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ---------------------------- |
| /opt/high-fortress-user                                 | Raíz de ejecución.                                                                                       | 755                          |
| /opt/high-fortress-user/secrets                         | Directorio reservado por el instalador. `secrets.conf` no se guarda aquí.                                | 700                          |
| /opt/high-fortress-user/src/config/global.conf                 | Configuración preparada cuando se usó el instalador curl. El mismo archivo está en `config/` en un clon. | 644                          |
| /opt/high-fortress-user/src/config/secrets.conf                | Secretos escritos por configure.sh. Permanece en la máquina.                                             | 600                          |
| /opt/high-fortress-user/src/hf                          | Lanzador.                                                                                                | 755                          |
| /opt/high-fortress-user/bin/aide-refresh-db.sh          | Reconstruye la base AIDE.                                                                                | 755                          |
| /opt/high-fortress-user/bin/chkrootkit-ignore-log.sh    | Registra las líneas chkrootkit reconocidas.                                                              | 755                          |
| /opt/high-fortress-user/bin/debsums-ignore-log.sh       | Registra las líneas debsums reconocidas.                                                                 | 755                          |
| /opt/high-fortress-user/cron/bin/*.sh                   | Scripts de control y mail.sh. Propietario root.                                                          | 750                          |
| /opt/high-fortress-user/cron/bin/mail.html              | Plantilla de correo.                                                                                     | 644                          |
| /opt/high-fortress-user/cron/bin/chkrootkit.ignore      | Patrones chkrootkit entregados.                                                                          | 664                          |
| /opt/high-fortress-user/cron/mail.conf                  | HF_MAIL_ALERTS, WATCHDOG_MAIL, PROJECT_NAME, MAIL_TEMPLATE.                                              | 600                          |
| /opt/high-fortress-user/cron/rkhunter-mirrors.sha256    | Huella de mirrors.dat después de una actualización lograda.                                              | 600                          |
| /etc/cron.d/high-fortress-user                          | Solo SHELL y PATH.                                                                                       | 600                          |
| /etc/systemd/system/hfu-boot-scan.service               | Unidad de la pasada de arranque.                                                                         | 644                          |
| /etc/systemd/system/hfu-boot-scan.timer                 | Lanza la pasada 2 minutos después del arranque.                                                          | 644                          |
| /etc/ssh/sshd_config.d/00-high-fortress-user.conf       | Política SSH de este puesto.                                                                             | 644                          |
| /etc/ssh/sshd_banner                                    | Banner de acceso.                                                                                        | 644                          |
| /etc/aide/aide.conf                                     | Política AIDE con CONFIG_BASE_DIR sustituido.                                                            | written by redirection       |
| /var/lib/aide/aide.db                                   | Base AIDE.                                                                                               | created by aide --init       |
| /etc/clamav/clamd.conf                                  | Rutas de acceso añadidas por service/clamav/configure.sh.                                                | package file, lines appended |
| /var/lib/clamav/quarantine                              | Directorio de cuarentena.                                                                                | 750                          |
| /etc/sudoers.d/high-fortress-user-clamav                | Permite la llamada sudo de VirusEvent.                                                                   | 440                          |
| /etc/systemd/system/clamav-clamonacc.service.d/hfu.conf | Dirige clamonacc al directorio de cuarentena. El nombre de la unidad es el del paquete.                  | written by redirection       |
| /etc/unbound/unbound.conf.d/high-fortress-user.conf     | Resolutor local.                                                                                         | 644                          |
| /etc/systemd/system/hfu-unbound-root-hints.service      | Actualiza las indicaciones raíz.                                                                         | 644                          |
| /etc/systemd/system/hfu-unbound-root-hints.path         | Unidad path de las indicaciones raíz.                                                                    | 644                          |
| /etc/apt/sources.list.d/lynis.list                      | Origen Lynis CISOfy.                                                                                     | 644                          |
| /etc/apt/keyrings/cisofy-software.gpg                   | Clave Lynis.                                                                                             | 644                          |
| /etc/apt/sources.list.d/mozilla.sources                 | Origen Thunderbird.                                                                                      | 644                          |
| /etc/apt/sources.list.d/brave-browser-release.sources   | Origen Brave.                                                                                            | 644                          |
| /etc/apt/apt.conf.d/51high-fortress-user                | Actualizaciones automáticas, reinicio cortado.                                                           | written by redirection       |
| /etc/sysctl.d/90-high-fortress-user.conf                | Sysctl del puesto.                                                                                       | 644                          |
| /etc/sysctl.d/99-zzz-high-fortress-user.conf            | Copia del archivo sysctl aplicada al final.                                                              | 644                          |
| /etc/lynis/custom.prf                                   | Perfil Lynis de este puesto.                                                                             | 644                          |
| /etc/security/pwquality.conf                            | Calidad de las contraseñas.                                                                              | written by redirection       |
| /etc/security/faillock.conf                             | Bloqueo de cuenta.                                                                                       | written by redirection       |
| /etc/audit/rules.d/00-high-fortress-user.rules          | Vigilancias de auditoría.                                                                                | 640                          |
