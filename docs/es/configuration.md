[README completo](README.md)

# Configuración

Los nombres y los valores de abajo son el `user/config/global.conf` entregado y `hfu_config_set_builtin_defaults`. Los corchetes de una pregunta son el valor que Intro conserva.

## Variables generales

| Nombre                     | Valor por defecto                                                | Efecto                                                                                             |
| -------------------------- | ---------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| HF_PREPARED                | 1                                                                | Debe valer 1, si no el control rechaza los archivos.                                               |
| PROJECT_NAME               | High-Fortress User                                               | Aparece en el correo. No se pregunta.                                                              |
| PROJECT_SLUG               | high-fortress-user                                               | Fijado por el control. Construye `CONFIG_BASE_DIR`.                                                |
| PROJECT_VERSION            | 0.2                                                              | Registrada. No se pregunta.                                                                        |
| CONFIG_BASE_DIR            | /opt/high-fortress-user                                          | Raíz de ejecución. Derivada de `PROJECT_SLUG`.                                                     |
| SECRETS_DIR                | /opt/high-fortress-user/secrets                                  | Creado en modo 700. `secrets.conf` no se escribe aquí.                                             |
| DEBUG_INSTALL_LOGS         | 0                                                                | Presente en el archivo. Los diarios de instalación van siempre a `<source>/logs/`.                |
| MODE_TEST                  | 1                                                                | Se pregunta. `1` omite la pregunta de retirada al final. `0` la hace.                              |
| LYNIS_MIN_SCORE            | 80                                                               | Índice de endurecimiento mínimo aceptado. No se pregunta.                                          |
| HFU_OS_ID                  | ubuntu                                                           | Fijado por el control.                                                                             |
| HFU_OS_VERSION             | 26.04                                                            | Fijado por el control.                                                                             |
| BANNER_MESSAGE             | text in global.conf                                              | Se escribe en `/etc/ssh/sshd_banner`. No se pregunta.                                              |
| SSH_BANNER_PATH            | /etc/ssh/sshd_banner                                             | Archivo del banner. No se pregunta.                                                                |
| SSH_SERVICE_NAME           | ssh                                                              | Nombre del servicio. No se pregunta.                                                               |
| SSH_MAX_AUTH_TRIES         | 4                                                                | sshd `MaxAuthTries`. No se pregunta.                                                               |
| SSH_CLIENT_ALIVE_INTERVAL  | 300                                                              | Intervalo sshd en segundos. No se pregunta.                                                        |
| SSH_CLIENT_ALIVE_COUNT_MAX | 2                                                                | Número de sondas sshd. No se pregunta.                                                             |
| SSH_LOGIN_GRACE_TIME       | 30                                                               | Plazo sshd en segundos. No se pregunta.                                                            |
| PWQUALITY_MINLEN           | 12                                                               | Longitud mínima en `/etc/security/pwquality.conf`. No se pregunta.                                 |
| FAILLOCK_DENY              | 8                                                                | Fallos antes del bloqueo. No se pregunta.                                                          |
| FAILLOCK_UNLOCK            | 600                                                              | Segundos de bloqueo. No se pregunta.                                                               |
| FAILLOCK_FAIL_INTERVAL     | 900                                                              | Ventana de recuento de los fallos. No se pregunta.                                                 |
| WATCHDOG_CPU_LIMIT         | 20                                                               | Cuota de CPU en porcentaje de la pasada de arranque. No se pregunta.                               |
| WATCHDOG_LIMIT_NICE        | 19                                                               | Valor nice de la pasada de arranque. No se pregunta.                                               |
| WATCHDOG_LIMIT_IONICE      | 3                                                                | Clase ionice guardada en el archivo. El temporizador usa `IOSchedulingClass=idle`. No se pregunta. |
| HF_MAIL_ALERTS             | 1 in the shipped file, 0 in the builtin default until you answer | Lo fija la respuesta sobre las alertas.                                                            |
| MAIL_TEMPLATE              | mail.html                                                        | Plantilla HTML copiada a `cron/bin`. No se pregunta.                                               |

## secrets.conf

El archivo se escribe en `config/`, junto a `global.conf`, modo `600`, propietario root. No se escribe en `SECRETS_DIR`. Los valores no se listan aquí.

| Nombre               | Dónde        | Regla                                                               |
| -------------------- | ------------ | ------------------------------------------------------------------- |
| UBUNTU_PRO_TOKEN     | secrets.conf | Se pregunta. Obligatorio. Letras y dígitos, de 6 a 100.             |
| POSTFIX_SMTP_LOGIN   | secrets.conf | Se pregunta solo si las alertas están activadas.                    |
| POSTFIX_MAIL_ADDRESS | secrets.conf | Dirección From. También se copia a `WATCHDOG_MAIL`.                 |
| POSTFIX_MAIL_PASS    | secrets.conf | Contraseña de aplicación, de 8 a 128 caracteres, espacios quitados. |
| POSTFIX_MAIL_SMTP    | secrets.conf | `host:puerto` sin corchetes.                                        |
| WATCHDOG_MAIL        | secrets.conf | El mismo valor que `POSTFIX_MAIL_ADDRESS`.                          |
| HF_SECRETS_PREPARED  | secrets.conf | Lo pone a 1 la escritura. No se pregunta.                           |

## Variables por servicio

| Nombre                        | Valor por defecto                         | Efecto                                                                       |
| ----------------------------- | ----------------------------------------- | ---------------------------------------------------------------------------- |
| OnAccessIncludePath           | Descargas y Escritorio                    | `xdg-user-dir`, o `$HOME/Downloads` y `$HOME/Desktop`.                       |
| OnAccessExcludePath           | $HOME/.steam and $HOME/.local/share/Steam | Los datos de Steam no se analizan al acceso.                                 |
| OnAccessExcludeUname          | clamav                                    | El usuario del analizador está excluido.                                     |
| OnAccessExcludeRootUID        | yes                                       | Root está excluido del análisis al acceso en este puesto.                    |
| OnAccessMaxFileSize           | 25M                                       | Los archivos más grandes no se analizan al acceso.                           |
| OnAccessPrevention            | yes                                       | Una detección se mueve a la cuarentena.                                      |
| quarantine                    | /var/lib/clamav/quarantine                | Modo 750, propietario clamav.                                                |
| hfu-boot-scan.timer OnBootSec | 2min                                      | `Persistent=false`. Una máquina ya encendida espera el próximo arranque.     |
| database_in                   | /var/lib/aide/aide.db                     | `__HF_BASE__` en `service/aide/aide.conf` se convierte en `CONFIG_BASE_DIR`. |

## Docker

Este puesto no tiene un árbol `docker/`. Este instalador no fija ninguna imagen, etiqueta, puerto ni volumen.

## No preguntado, y generado

Los valores preguntados son el token de Ubuntu Pro, la elección de las alertas, los campos SMTP cuando las alertas están activadas, y `MODE_TEST`. Todo lo demás de las tablas no se pregunta. No se genera nada con `openssl`. `HF_MAIL_ALERTS` vale `1` o `0` según la respuesta. Los campos de correo vacíos se escriben cuando las alertas se cortan.
