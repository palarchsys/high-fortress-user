[Vollständiges README](README.md)

# Konfiguration

Die Namen und Vorgaben unten sind die mitgelieferte `user/config/global.conf` und `hfu_config_set_builtin_defaults`. Die Klammern einer Frage sind der Wert, den Enter behält.

## Allgemeine Variablen

| Name                       | Vorgabe                                                          | Wirkung                                                                                                |
| -------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| HF_PREPARED                | 1                                                                | Muss 1 sein, sonst lehnt die Prüfung die Dateien ab.                                                   |
| PROJECT_NAME               | High-Fortress User                                               | Steht in der Post. Wird nicht gefragt.                                                                 |
| PROJECT_SLUG               | high-fortress-user                                               | Von der Prüfung festgeschrieben. Baut `CONFIG_BASE_DIR`.                                               |
| PROJECT_VERSION            | 0.2                                                              | Gespeichert. Wird nicht gefragt.                                                                       |
| CONFIG_BASE_DIR            | /opt/high-fortress-user                                          | Laufzeitwurzel. Abgeleitet von `PROJECT_SLUG`.                                                         |
| SECRETS_DIR                | /opt/high-fortress-user/secrets                                  | Angelegt mit Modus 700. `secrets.conf` wird hier nicht geschrieben.                                    |
| DEBUG_INSTALL_LOGS         | 0                                                                | Steht in der Datei. Installationsjournale gehen immer nach `<source>/logs/`.                           |
| MODE_TEST                  | 1                                                                | Wird gefragt. `1` überspringt die Entfernungsfrage am Ende. `0` stellt sie.                            |
| LYNIS_MIN_SCORE            | 80                                                               | Mindestens akzeptierter Härtungsindex. Wird nicht gefragt.                                             |
| HFU_OS_ID                  | ubuntu                                                           | Von der Prüfung festgeschrieben.                                                                       |
| HFU_OS_VERSION             | 26.04                                                            | Von der Prüfung festgeschrieben.                                                                       |
| BANNER_MESSAGE             | text in global.conf                                              | Wird nach `/etc/ssh/sshd_banner` geschrieben. Wird nicht gefragt.                                      |
| SSH_BANNER_PATH            | /etc/ssh/sshd_banner                                             | Bannerdatei. Wird nicht gefragt.                                                                       |
| SSH_SERVICE_NAME           | ssh                                                              | Dienstname. Wird nicht gefragt.                                                                        |
| SSH_MAX_AUTH_TRIES         | 4                                                                | sshd `MaxAuthTries`. Wird nicht gefragt.                                                               |
| SSH_CLIENT_ALIVE_INTERVAL  | 300                                                              | sshd-Intervall in Sekunden. Wird nicht gefragt.                                                        |
| SSH_CLIENT_ALIVE_COUNT_MAX | 2                                                                | sshd-Sondenzahl. Wird nicht gefragt.                                                                   |
| SSH_LOGIN_GRACE_TIME       | 30                                                               | sshd-Gnadenfrist in Sekunden. Wird nicht gefragt.                                                      |
| PWQUALITY_MINLEN           | 12                                                               | Mindestlänge in `/etc/security/pwquality.conf`. Wird nicht gefragt.                                    |
| FAILLOCK_DENY              | 8                                                                | Fehlschläge vor der Sperre. Wird nicht gefragt.                                                        |
| FAILLOCK_UNLOCK            | 600                                                              | Sperrsekunden. Wird nicht gefragt.                                                                     |
| FAILLOCK_FAIL_INTERVAL     | 900                                                              | Fenster für die Fehlzählung. Wird nicht gefragt.                                                       |
| WATCHDOG_CPU_LIMIT         | 20                                                               | CPU-Quote in Prozent der Startprüfung. Wird nicht gefragt.                                             |
| WATCHDOG_LIMIT_NICE        | 19                                                               | Nice-Wert der Startprüfung. Wird nicht gefragt.                                                        |
| WATCHDOG_LIMIT_IONICE      | 3                                                                | In der Datei gespeicherte Ionice-Klasse. Der Timer nutzt `IOSchedulingClass=idle`. Wird nicht gefragt. |
| HF_MAIL_ALERTS             | 1 in the shipped file, 0 in the builtin default until you answer | Gesetzt durch die Alarmantwort.                                                                        |
| MAIL_TEMPLATE              | mail.html                                                        | HTML-Vorlage, kopiert nach `cron/bin`. Wird nicht gefragt.                                             |

## secrets.conf

Die Datei wird in `config/`, neben `global.conf` geschrieben, Modus `600`, Eigentümer root. Sie wird nicht in `SECRETS_DIR` geschrieben. Die Werte stehen hier nicht.

| Name                 | Wo           | Regel                                                          |
| -------------------- | ------------ | -------------------------------------------------------------- |
| UBUNTU_PRO_TOKEN     | secrets.conf | Wird gefragt. Erforderlich. Buchstaben und Ziffern, 6 bis 100. |
| POSTFIX_SMTP_LOGIN   | secrets.conf | Nur wenn die Alarme eingeschaltet sind.                        |
| POSTFIX_MAIL_ADDRESS | secrets.conf | From-Adresse. Auch nach `WATCHDOG_MAIL` kopiert.               |
| POSTFIX_MAIL_PASS    | secrets.conf | Anwendungskennwort, 8 bis 128 Zeichen, Leerzeichen entfernt.   |
| POSTFIX_MAIL_SMTP    | secrets.conf | `Host:Port` ohne Klammern.                                     |
| WATCHDOG_MAIL        | secrets.conf | Gleicher Wert wie `POSTFIX_MAIL_ADDRESS`.                      |
| HF_SECRETS_PREPARED  | secrets.conf | Vom Schreiber auf 1 gesetzt. Wird nicht gefragt.               |

## Dienstvariablen

| Name                          | Vorgabe                                   | Wirkung                                                                           |
| ----------------------------- | ----------------------------------------- | --------------------------------------------------------------------------------- |
| OnAccessIncludePath           | Downloads und Desktop                     | `xdg-user-dir`, oder `$HOME/Downloads` und `$HOME/Desktop`.                       |
| OnAccessExcludePath           | $HOME/.steam and $HOME/.local/share/Steam | Steam-Daten werden beim Zugriff nicht geprüft.                                    |
| OnAccessExcludeUname          | clamav                                    | Der Scanner-Benutzer ist ausgeschlossen.                                          |
| OnAccessExcludeRootUID        | yes                                       | Root ist auf diesem Arbeitsplatz von der Zugriffsprüfung ausgeschlossen.          |
| OnAccessMaxFileSize           | 25M                                       | Größere Dateien werden beim Zugriff nicht geprüft.                                |
| OnAccessPrevention            | yes                                       | Ein Fund wird in die Quarantäne verschoben.                                       |
| quarantine                    | /var/lib/clamav/quarantine                | Modus 750, Eigentümer clamav.                                                     |
| hfu-boot-scan.timer OnBootSec | 2min                                      | `Persistent=false`. Eine bereits laufende Maschine wartet auf den nächsten Start. |
| database_in                   | /var/lib/aide/aide.db                     | `__HF_BASE__` in `service/aide/aide.conf` wird `CONFIG_BASE_DIR`.                 |

## Docker

Dieser Arbeitsplatz hat keinen `docker/`-Baum. Dieses Installationsprogramm setzt kein Image, kein Tag, keinen Port und kein Volume.

## Nicht gefragt, und erzeugt

Gefragt werden das Ubuntu-Pro-Token, die Alarmwahl, die SMTP-Felder wenn die Alarme eingeschaltet sind, und `MODE_TEST`. Alles andere in den Tabellen wird nicht gefragt. Nichts wird mit `openssl` erzeugt. `HF_MAIL_ALERTS` ist `1` oder `0` je nach Antwort. Leere Mail-Felder werden geschrieben, wenn die Alarme aus sind.
