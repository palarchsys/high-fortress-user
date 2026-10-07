# High-Fortress User

## Descripción

High-Fortress User prepara un puesto Ubuntu 26.04. Instala los programas de escritorio, el resolutor DNS local, el cortafuegos y los controles de seguridad.

La cuenta Ubuntu ya creada en la máquina no se sustituye. El instalador no crea una segunda cuenta.

`secrets.conf` permanece en la máquina. No lo copie en un mensaje, un ticket o un repositorio.

## Antes de comenzar

### Sistema

Ubuntu 26.04. Una instalación nueva es preferible. Use una consola local o la sesión gráfica ya abierta. La máquina necesita Internet.

### Acceso

Usted necesita `sudo` para `./hf configure`, `./hf run` y los controles.

### Necesidades externas

| Necesidad                | Enlace y procedimiento                                                                                                                                                                                                                      |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Token de Ubuntu Pro      | Obligatorio. Abra [https://ubuntu.com/pro/dashboard](https://ubuntu.com/pro/dashboard) y copie el token. `configure.sh` acepta solo letras y dígitos, longitud de 6 a 100, sin espacio.                                                     |
| Contraseña de aplicación | Se pide solo si usted activa las alertas. Use la contraseña de aplicación del proveedor de correo. No escriba nunca la contraseña de la cuenta. Longitud de 8 a 128. Los espacios escritos se quitan.                                       |
| Servidor SMTP            | Se pide solo si las alertas están activadas. Forma `host:puerto`. El ejemplo de `configure.sh` es `smtp-mail.outlook.com:587`. Los corchetes se rechazan. `swaks` envía un mensaje de prueba. La línea de éxito es `Essai d'envoi accepté.` |

## Instalación

### Curl

`install.sh` también instala `curl`, `ca-certificates` y `tar`, descarga la rama `main` y escribe las fuentes en `/opt/high-fortress-user/src`. Después ejecuta `scripts/configure.sh`. Si `global.conf` ya contiene `HF_PREPARED=1`, si `secrets.conf` existe y si `scripts/configure.sh --check` pasa, ejecuta `scripts/run.sh` en su lugar.

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git swaks tar
curl -fsSL https://raw.githubusercontent.com/palarchsys/high-fortress-user/main/install.sh | sudo bash
```

### Clon

El clon permanece en el directorio creado por `git clone`. `sudo ./hf configure` se ejecuta en ese directorio. El instalador curl es la orden que copia las fuentes a `/opt/high-fortress-user/src`.

```bash
git clone https://github.com/palarchsys/high-fortress-user
cd high-fortress-user
sudo ./hf configure
```

## Acción de configure.sh

`sudo ./hf configure` hace las preguntas de abajo, escribe `global.conf` en modo `644` y `secrets.conf` en modo `600` como root, y después inicia `scripts/run.sh`. `secrets.conf` no sale de la máquina.

| Pregunta         | Respuesta esperada                                                                                                                                                                   | Intro conserva                                               |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------ |
| Jeton Ubuntu Pro | Letras y dígitos, de 6 a 100, sin espacio. Obligatorio.                                                                                                                              | Un token ya guardado. La primera vez no hay token guardado.  |
| Activer          | `Y` o `y` activa las alertas. `n` o `non` las corta. Cualquier otra respuesta muestra `Répondez Y ou n.`                                                                             | Nada. La pregunta no tiene valor por defecto.                |
| Serveur          | `host:puerto`, por ejemplo `smtp-mail.outlook.com:587`. Sin corchetes. Solo si las alertas están activadas.                                                                          | Nada la primera vez.                                         |
| Login            | Una dirección de correo.                                                                                                                                                             | Nada la primera vez.                                         |
| Password         | La contraseña de aplicación del proveedor, de 8 a 128 caracteres. Los espacios se quitan. Las comillas, `$`, `\` y la comilla inversa se rechazan. Nunca la contraseña de la cuenta. | Nada. Una segunda línea pide la confirmación.                |
| From             | Una dirección de correo. `WATCHDOG_MAIL` recibe la misma dirección.                                                                                                                  | Nada la primera vez.                                         |
| Mode test        | `0` o `1`.                                                                                                                                                                           | El valor actual de `MODE_TEST`. El valor entregado es `[1]`. |

Cuando las alertas están activadas, `swaks` debe recibir un `250` SMTP. La línea de éxito es `Essai d'envoi accepté.` `HF_MAIL_ALERTS` pasa a `1`. Cuando las alertas se cortan, la línea de éxito es `Alertes e-mail coupées. Les contrôles partiront sans envoi.` y las variables de correo se vacían.

Los valores que no se preguntan se escriben desde `hfu_config_set_builtin_defaults` y desde el `global.conf` entregado. Están en [configuration.md](configuration.md). No se genera ninguna contraseña aleatoria.

## Programas y servicios instalados

| Nombre                                          | Origen                                                                                  | Función                                                                                                                        |
| ----------------------------------------------- | --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| openssh-server                                  | Ubuntu archive                                                                          | Servidor SSH. El acceso de root se rechaza. La autenticación por contraseña permanece activada.                                |
| ufw                                             | Ubuntu archive                                                                          | Cortafuegos del equipo.                                                                                                        |
| fail2ban                                        | Ubuntu archive                                                                          | Bloquea los fallos de autenticación repetidos.                                                                                 |
| auditd                                          | Ubuntu archive                                                                          | Escribe las reglas de auditoría de las rutas elegidas.                                                                         |
| rkhunter                                        | Ubuntu archive                                                                          | Control de rootkits y de propiedades de archivos.                                                                              |
| chkrootkit                                      | Ubuntu archive                                                                          | Control de rootkits. El binario es `/usr/sbin/chkrootkit`.                                                                     |
| clamav                                          | Ubuntu archive                                                                          | Análisis al acceso y análisis al arranque.                                                                                     |
| crowdsec                                        | https://packagecloud.io/crowdsec/crowdsec/any any main                                  | Decisiones de seguridad locales.                                                                                               |
| debsums                                         | Ubuntu archive                                                                          | Sumas de control de los archivos de los paquetes.                                                                              |
| unbound                                         | Ubuntu archive                                                                          | Resolutor DNS local en `127.0.0.1` y `::1`, puerto 53.                                                                         |
| apparmor                                        | Ubuntu archive, plus `service/apparmor/userns.sh`                                       | Perfiles de la distribución, más perfiles userns para Brave, Discord, Thunderbird y Steam cuando ningún perfil cubre ya Steam. |
| aide                                            | Ubuntu archive                                                                          | Base de integridad `/var/lib/aide/aide.db`.                                                                                    |
| unattended-upgrades                             | Ubuntu archive                                                                          | Orígenes de seguridad y el origen Thunderbird. `Automatic-Reboot` vale `false`.                                                |
| postfix                                         | Ubuntu archive, only when `HF_MAIL_ALERTS=1`                                            | Envía el correo de alerta.                                                                                                     |
| lynis                                           | https://packages.cisofy.com/community/lynis/deb/ stable main                            | Auditoría de endurecimiento. La clave es `https://packages.cisofy.com/keys/cisofy-software-public.key`.                        |
| ubuntu-pro-client                               | Ubuntu archive                                                                          | Asocia el token de Ubuntu Pro.                                                                                                 |
| brave-browser                                   | https://brave-browser-apt-release.s3.brave.com/brave-browser.sources                    | Navegador.                                                                                                                     |
| thunderbird                                     | https://packages.mozilla.org/apt suite thunderbird-deb                                  | Cliente de correo de los paquetes Mozilla, no el snap.                                                                         |
| keepassxc                                       | Ubuntu archive                                                                          | Base de contraseñas.                                                                                                           |
| discord                                         | https://discord.com/api/download?platform=linux&format=deb                              | Cliente Discord.                                                                                                               |
| Vencord                                         | https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli-linux | Instalado en el cliente Discord por `service/desktop/install.sh`.                                                              |
| acct, sysstat, libpam-pwquality                 | Ubuntu archive                                                                          | Contabilidad de procesos, estadísticas de actividad, calidad de las contraseñas.                                               |
| rng-tools-debian, haveged                       | Ubuntu archive                                                                          | Fuentes de entropía.                                                                                                           |
| apt-listchanges, needrestart, apt-show-versions | Ubuntu archive                                                                          | Avisos de cambios de paquetes y controles de reinicio.                                                                         |

## Qué hace la máquina después de la instalación

| Tema        | Comportamiento                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Cortafuegos | `ufw default deny incoming`, `ufw default allow outgoing`, `ufw default allow routed`. El bucle local se permite en ambos sentidos. No se añade ninguna otra regla de entrada.                                                                                                                                                                                                                                                                                                    |
| DNS         | Unbound escucha en `127.0.0.1` y `::1`. systemd-resolved y NetworkManager apuntan a ese resolutor. El DNS IPv6 permanece activado (`do-ip6: yes`).                                                                                                                                                                                                                                                                                                                                |
| SSH         | `PermitRootLogin no`. `PasswordAuthentication yes`. `PubkeyAuthentication yes`. Banner `/etc/ssh/sshd_banner`. `MaxAuthTries 4`.                                                                                                                                                                                                                                                                                                                                                  |
| Núcleo      | `/etc/sysctl.d/90-high-fortress-user.conf` se copia a `/etc/sysctl.d/99-zzz-high-fortress-user.conf`. IPv6 permanece activado. Las redirecciones IPv6 y el source routing se rechazan. Los user namespaces permanecen activados. `dccp`, `sctp`, `rds` y `tipc` quedan en lista negra. Los sistemas de archivos no usados quedan en lista negra. Los volcados de núcleo quedan en 0. `PWQUALITY_MINLEN` vale 12.                                                                  |
| AppArmor    | Los perfiles de la distribución permanecen. `service/apparmor/userns.sh` añade `hfu-brave`, `hfu-discord`, `hfu-thunderbird` y `hfu-steam` cuando Steam no está ya cubierto.                                                                                                                                                                                                                                                                                                      |
| Controles   | `hfu-boot-scan.timer` lanza `boot-scan.sh` 2 minutos después del arranque (`OnBootSec=2min`, `Persistent=false`). La pasada lanza AIDE, rkhunter, chkrootkit, ClamAV y debsums. `Nice` vale `WATCHDOG_LIMIT_NICE` (19), `IOSchedulingClass=idle`, `CPUQuota` vale `WATCHDOG_CPU_LIMIT` (20 %). `/etc/cron.d/high-fortress-user` solo contiene `SHELL` y `PATH`. La crontab del usuario no se modifica. El correo sale solo cuando un control encuentra algo y `HF_MAIL_ALERTS=1`. |
| Lynis       | `LYNIS_MIN_SCORE` vale 80. `verify/workstation.sh` acepta un `hardening_index` superior o igual a ese umbral.                                                                                                                                                                                                                                                                                                                                                                     |
| Diarios     | Los diarios de instalación están en `<source>/logs/install-YYYYMMDD-HHMMSS-user/`. Los diarios de seguridad están en `/opt/high-fortress-user/cron/security_logs/`. El almacenamiento de journald es persistente.                                                                                                                                                                                                                                                                |
| Paquetes    | Los snaps Firefox y Thunderbird se retiran. `snapd` se conserva. El paquete `firefox` queda retenido. En amd64 se activa la arquitectura i386. Steam no lo instala este programa.                                                                                                                                                                                                                                                                                                 |

## Correos de alerta

El correo sale solo si `HF_MAIL_ALERTS=1`, si `WATCHDOG_MAIL` está definido y si `/opt/high-fortress-user/cron/bin/send.sh` es ejecutable. Un control limpio no envía correo. Si una línea del diario es desconocida, no lance la orden. Conserve el correo.

### AIDE

El mensaje contiene la línea de resumen y un extracto del diario, después la nota y el bloque de orden. La ruta del diario en el correo es el archivo real. La forma es `/opt/high-fortress-user/cron/security_logs/aide-YYYYMMDD-HHMMSS.log`.

```bash
sudo bash /opt/high-fortress-user/bin/aide-refresh-db.sh
```

La orden reconstruye la base AIDE a partir del disco actual. La línea de éxito es `Base de référence AIDE enregistrée.`

### chkrootkit

El mensaje contiene el resumen y el extracto del diario, después la nota y la orden. El ejemplo de abajo muestra la forma. El correo contiene la ruta real.

```bash
sudo bash /opt/high-fortress-user/bin/chkrootkit-ignore-log.sh '/opt/high-fortress-user/cron/security_logs/chkrootkit-YYYYMMDD-HHMMSS.log'
```

La orden registra las líneas de ese diario en `/opt/high-fortress-user/cron/chkrootkit.local.ignore`. La línea de éxito es `Aucune nouvelle détection à enregistrer.` cuando no hay nada nuevo, o `N détection(s) enregistrée(s) dans /opt/high-fortress-user/cron/chkrootkit.local.ignore`.

### debsums

El mensaje contiene el resumen y el extracto del diario, después la nota y la orden. El ejemplo de abajo muestra la forma. El correo contiene la ruta real.

```bash
sudo bash /opt/high-fortress-user/bin/debsums-ignore-log.sh '/opt/high-fortress-user/cron/security_logs/debsums-YYYYMMDD-HHMMSS.log'
```

La orden registra las líneas de ese diario en `/opt/high-fortress-user/cron/debsums.local.ignore`. La línea de éxito es `Aucune nouvelle détection à enregistrer.` o `N détection(s) enregistrée(s) dans /opt/high-fortress-user/cron/debsums.local.ignore`. Una línea de `/var/lib/rkhunter/db/mirrors.dat` se retira antes del correo solo si su SHA-256 actual es igual a `/opt/high-fortress-user/cron/rkhunter-mirrors.sha256`. Cualquier otro contenido permanece en el correo. No ignore el archivo entero.

### ClamAV al acceso

El mensaje contiene la firma, el nombre del archivo, la ruta de origen y la ruta de cuarentena, después la nota y una orden `sudo ls`. La orden se construye para el archivo en cuarentena nombrado en el correo. Un archivo cuyo nombre coincide con `.clamav-quarantine-lock.*` no envía correo. El script sale con 0 antes del diario y antes de `log_alert`.

```bash
sudo ls -la -- /var/lib/clamav/quarantine/<file>
```

El ejemplo muestra la forma. El correo contiene la ruta real, entre comillas. La orden lista ese archivo y no lo devuelve a su sitio. `ls` muestra la entrada. No hay línea de éxito del instalador.

### Análisis ClamAV al arranque

El mensaje contiene el resumen y el extracto del diario. Este correo no añade un bloque de orden. La forma del diario es `/opt/high-fortress-user/cron/security_logs/clamav-YYYYMMDD-HHMMSS.log`.

### rkhunter

El mensaje contiene el resumen y el extracto del diario. Este correo no añade un bloque de orden. Una suma distinta añade la línea `mirrors.dat modifié hors rkhunter --update`. Esa línea no es una orden. La forma del diario es `/opt/high-fortress-user/cron/security_logs/rkhunter-YYYYMMDD-HHMMSS.log`.

## Comandos después de la instalación

Lance estas órdenes desde el directorio de las fuentes (`/opt/high-fortress-user/src` después del instalador curl, o el directorio del clon).

### hf check

```bash
sudo ./hf check
```

Comprueba `global.conf` y `secrets.conf`. La línea de éxito es `Configuration conforme`. `secrets.conf` está en modo `600`, así que `sudo` es necesario para leerlo.

### hf run

```bash
sudo ./hf run
```

Lanza la instalación a partir de los archivos preparados. El instalador se niega a empezar cuando el control no pasa.

### verify/alerts.sh

```bash
sudo bash verify/alerts.sh
```

Comprueba el temporizador de arranque, ClamAV al acceso y la ruta del correo. Sin `--no-send`, sale una sonda cuando las alertas están activadas. El asunto termina por `Contrôle`. La línea de éxito es `Résultat : OK`.

```bash
sudo bash verify/alerts.sh --no-send
```

El mismo control sin enviar la sonda.

### verify/workstation.sh

```bash
sudo bash verify/workstation.sh "$PWD"
```

Lanza la verificación del puesto. La línea final tiene la forma `Check : N OK / N WARN / N FAIL`.

### hf lynis

```bash
sudo ./hf lynis
```

Lanza `lynis audit system --quick --no-colors` y escribe el informe bajo `<source>/logs/lynis-<stamp>/`.

### Base AIDE

```bash
sudo bash /opt/high-fortress-user/bin/aide-refresh-db.sh
```

Reconstruye `/var/lib/aide/aide.db`. La línea de éxito es `Base de référence AIDE enregistrée.`

### Huella de los espejos rkhunter

```bash
sudo bash /opt/high-fortress-user/cron/bin/record-mirrors.sh save
```

Escribe el SHA-256 de `/var/lib/rkhunter/db/mirrors.dat` en `/opt/high-fortress-user/cron/rkhunter-mirrors.sha256` en modo `600`. `rkhunter.sh` guarda esta huella solo después de un `rkhunter --update` que devuelve 0 o 2.

## Páginas detalladas

| Tema                               | Página                               |
| ---------------------------------- | ------------------------------------ |
| Variables generales y por servicio | [configuration.md](configuration.md) |
| Herramientas de vigilancia         | [surveillance.md](surveillance.md)   |
| Árbol instalado                    | [architecture.md](architecture.md)   |
| Archivos instalados                | [files.md](files.md)                 |
| Diarios                            | [logs.md](logs.md)                   |
