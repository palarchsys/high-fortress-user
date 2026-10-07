# High-Fortress User

## Beschreibung

High-Fortress User bereitet einen Ubuntu-26.04-Arbeitsplatz vor. Es installiert die Desktop-Programme, den lokalen DNS-Resolver, die Firewall und die Sicherheitskontrollen.

Das bereits angelegte Ubuntu-Konto auf der Maschine wird nicht ersetzt. Das Installationsprogramm legt kein zweites Konto an.

`secrets.conf` bleibt auf der Maschine. Kopieren Sie es nicht in eine Nachricht, ein Ticket oder ein Repository.

## Bevor Sie beginnen

### System

Ubuntu 26.04. Eine Neuinstallation ist vorzuziehen. Benutzen Sie eine lokale Konsole oder die bereits geöffnete grafische Sitzung. Die Maschine braucht Internetzugang.

### Zugang

Sie brauchen `sudo` für `./hf configure`, `./hf run` und die Kontrollen.

### Externe Voraussetzungen

| Bedarf             | Link und Verfahren                                                                                                                                                                                                                    |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ubuntu-Pro-Token   | Erforderlich. Öffnen Sie [https://ubuntu.com/pro/dashboard](https://ubuntu.com/pro/dashboard) und kopieren Sie das Token. `configure.sh` akzeptiert nur Buchstaben und Ziffern, Länge 6 bis 100, ohne Leerzeichen.                    |
| Anwendungskennwort | Nur wenn Sie die Alarme einschalten. Benutzen Sie das Anwendungskennwort des Mail-Anbieters. Geben Sie nie das Kontokennwort ein. Länge 8 bis 128. Eingegebene Leerzeichen werden entfernt.                                           |
| SMTP-Server        | Nur wenn die Alarme eingeschaltet sind. Form `Host:Port`. Das Beispiel in `configure.sh` ist `smtp-mail.outlook.com:587`. Klammern werden abgelehnt. `swaks` sendet eine Testnachricht. Die Erfolgszeile ist `Essai d'envoi accepté.` |

## Installation

### Curl

`install.sh` installiert außerdem `curl`, `ca-certificates` und `tar`, lädt den Zweig `main` und schreibt die Quellen nach `/opt/high-fortress-user/src`. Danach startet es `scripts/configure.sh`. Wenn `global.conf` bereits `HF_PREPARED=1` enthält, `secrets.conf` existiert und `scripts/configure.sh --check` besteht, startet es stattdessen `scripts/run.sh`.

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git swaks tar
curl -fsSL https://raw.githubusercontent.com/palarchsys/high-fortress-user/main/install.sh | sudo bash
```

### Klon

Der Klon bleibt in dem Verzeichnis, das `git clone` anlegt. `sudo ./hf configure` läuft in diesem Verzeichnis. Der Curl-Installer ist der Befehl, der die Quellen nach `/opt/high-fortress-user/src` kopiert.

```bash
git clone https://github.com/palarchsys/high-fortress-user
cd high-fortress-user
sudo ./hf configure
```

## Aktion von configure.sh

`sudo ./hf configure` stellt die folgenden Fragen, schreibt `global.conf` mit Modus `644` und `secrets.conf` mit Modus `600` als root und startet dann `scripts/run.sh`. `secrets.conf` verlässt die Maschine nicht.

| Frage            | Erwartete Antwort                                                                                                                                                        | Enter behält                                                                   |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| Jeton Ubuntu Pro | Buchstaben und Ziffern, 6 bis 100, ohne Leerzeichen. Erforderlich.                                                                                                       | Ein bereits gespeichertes Token. Ein erster Lauf hat kein gespeichertes Token. |
| Activer          | `Y` oder `y` schaltet die Alarme ein. `n` oder `non` schaltet sie aus. Jede andere Antwort zeigt `Répondez Y ou n.`                                                      | Nichts. Die Frage hat keinen Vorgabewert.                                      |
| Serveur          | `Host:Port`, zum Beispiel `smtp-mail.outlook.com:587`. Ohne Klammern. Nur wenn die Alarme eingeschaltet sind.                                                            | Nichts beim ersten Lauf.                                                       |
| Login            | Eine E-Mail-Adresse.                                                                                                                                                     | Nichts beim ersten Lauf.                                                       |
| Password         | Das Anwendungskennwort des Anbieters, 8 bis 128 Zeichen. Leerzeichen werden entfernt. Anführungszeichen, `$`, `\` und Backticks werden abgelehnt. Nie das Kontokennwort. | Nichts. Eine zweite Zeile verlangt die Bestätigung.                            |
| From             | Eine E-Mail-Adresse. `WATCHDOG_MAIL` erhält dieselbe Adresse.                                                                                                            | Nichts beim ersten Lauf.                                                       |
| Mode test        | `0` oder `1`.                                                                                                                                                            | Der aktuelle Wert von `MODE_TEST`. Der mitgelieferte Vorgabewert ist `[1]`.    |

Wenn die Alarme eingeschaltet sind, muss `swaks` ein SMTP-`250` erhalten. Die Erfolgszeile ist `Essai d'envoi accepté.` `HF_MAIL_ALERTS` wird `1`. Wenn die Alarme aus sind, ist die Erfolgszeile `Alertes e-mail coupées. Les contrôles partiront sans envoi.` und die Mail-Variablen werden geleert.

Werte, die nicht gefragt werden, kommen aus `hfu_config_set_builtin_defaults` und aus der mitgelieferten `global.conf`. Sie stehen in [configuration.md](configuration.md). Es wird kein Zufallskennwort erzeugt.

## Installierte Software und Dienste

| Name                                            | Herkunft                                                                                | Rolle                                                                                                                     |
| ----------------------------------------------- | --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| openssh-server                                  | Ubuntu archive                                                                          | SSH-Server. Root-Anmeldung ist abgelehnt. Kennwortanmeldung bleibt eingeschaltet.                                         |
| ufw                                             | Ubuntu archive                                                                          | Host-Firewall.                                                                                                            |
| fail2ban                                        | Ubuntu archive                                                                          | Sperrt wiederholte Anmeldefehlschläge.                                                                                    |
| auditd                                          | Ubuntu archive                                                                          | Schreibt Audit-Regeln für ausgewählte Pfade.                                                                              |
| rkhunter                                        | Ubuntu archive                                                                          | Rootkit- und Dateieigenschaftsprüfung.                                                                                    |
| chkrootkit                                      | Ubuntu archive                                                                          | Rootkit-Prüfung. Die Binärdatei ist `/usr/sbin/chkrootkit`.                                                               |
| clamav                                          | Ubuntu archive                                                                          | Prüfung beim Zugriff und Prüfung beim Start.                                                                              |
| crowdsec                                        | https://packagecloud.io/crowdsec/crowdsec/any any main                                  | Lokale Sicherheitsentscheidungen.                                                                                         |
| debsums                                         | Ubuntu archive                                                                          | Prüfsummen der Paketdateien.                                                                                              |
| unbound                                         | Ubuntu archive                                                                          | Lokaler DNS-Resolver auf `127.0.0.1` und `::1`, Port 53.                                                                  |
| apparmor                                        | Ubuntu archive, plus `service/apparmor/userns.sh`                                       | Distributionsprofile sowie userns-Profile für Brave, Discord, Thunderbird und Steam, wenn noch kein Profil Steam abdeckt. |
| aide                                            | Ubuntu archive                                                                          | Dateiintegritätsdatenbank `/var/lib/aide/aide.db`.                                                                        |
| unattended-upgrades                             | Ubuntu archive                                                                          | Sicherheitsherkünfte und die Thunderbird-Herkunft. `Automatic-Reboot` ist `false`.                                        |
| postfix                                         | Ubuntu archive, only when `HF_MAIL_ALERTS=1`                                            | Sendet die Alarmpost.                                                                                                     |
| lynis                                           | https://packages.cisofy.com/community/lynis/deb/ stable main                            | Härtungsaudit. Der Schlüssel ist `https://packages.cisofy.com/keys/cisofy-software-public.key`.                           |
| ubuntu-pro-client                               | Ubuntu archive                                                                          | Bindet das Ubuntu-Pro-Token an.                                                                                           |
| brave-browser                                   | https://brave-browser-apt-release.s3.brave.com/brave-browser.sources                    | Webbrowser.                                                                                                               |
| thunderbird                                     | https://packages.mozilla.org/apt suite thunderbird-deb                                  | Mail-Client aus Mozilla-Paketen, nicht das Snap.                                                                          |
| keepassxc                                       | Ubuntu archive                                                                          | Kennwortdatenbank.                                                                                                        |
| discord                                         | https://discord.com/api/download?platform=linux&format=deb                              | Discord-Client.                                                                                                           |
| Vencord                                         | https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli-linux | Von `service/desktop/install.sh` in den Discord-Client installiert.                                                       |
| acct, sysstat, libpam-pwquality                 | Ubuntu archive                                                                          | Prozessabrechnung, Aktivitätsstatistik, Kennwortqualität.                                                                 |
| rng-tools-debian, haveged                       | Ubuntu archive                                                                          | Entropiequellen.                                                                                                          |
| apt-listchanges, needrestart, apt-show-versions | Ubuntu archive                                                                          | Paketänderungshinweise und Neustartprüfungen.                                                                             |

## Was die Maschine nach der Installation tut

| Thema      | Verhalten                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Firewall   | `ufw default deny incoming`, `ufw default allow outgoing`, `ufw default allow routed`. Loopback ist in beide Richtungen erlaubt. Es wird keine weitere eingehende Erlaubnis hinzugefügt.                                                                                                                                                                                                                                                                                              |
| DNS        | Unbound lauscht auf `127.0.0.1` und `::1`. systemd-resolved und NetworkManager zeigen auf diesen Resolver. IPv6-DNS bleibt eingeschaltet (`do-ip6: yes`).                                                                                                                                                                                                                                                                                                                             |
| SSH        | `PermitRootLogin no`. `PasswordAuthentication yes`. `PubkeyAuthentication yes`. Banner `/etc/ssh/sshd_banner`. `MaxAuthTries 4`.                                                                                                                                                                                                                                                                                                                                                      |
| Kernel     | `/etc/sysctl.d/90-high-fortress-user.conf` wird nach `/etc/sysctl.d/99-zzz-high-fortress-user.conf` kopiert. IPv6 bleibt eingeschaltet. IPv6-Redirects und Source-Routing werden abgelehnt. User-Namespaces bleiben eingeschaltet. `dccp`, `sctp`, `rds` und `tipc` werden gesperrt. Ungenutzte Dateisysteme werden gesperrt. Core-Dumps stehen auf 0. `PWQUALITY_MINLEN` ist 12.                                                                                                     |
| AppArmor   | Die Distributionsprofile bleiben. `service/apparmor/userns.sh` fügt `hfu-brave`, `hfu-discord`, `hfu-thunderbird` und `hfu-steam` hinzu, wenn Steam nicht bereits abgedeckt ist.                                                                                                                                                                                                                                                                                                      |
| Kontrollen | `hfu-boot-scan.timer` startet `boot-scan.sh` 2 Minuten nach dem Start (`OnBootSec=2min`, `Persistent=false`). Der Lauf startet AIDE, rkhunter, chkrootkit, ClamAV und debsums. `Nice` ist `WATCHDOG_LIMIT_NICE` (19), `IOSchedulingClass=idle`, `CPUQuota` ist `WATCHDOG_CPU_LIMIT` (20 %). `/etc/cron.d/high-fortress-user` enthält nur `SHELL` und `PATH`. Die Benutzer-Crontab wird nicht geändert. Post geht nur ab, wenn eine Kontrolle etwas findet und `HF_MAIL_ALERTS=1` ist. |
| Lynis      | `LYNIS_MIN_SCORE` ist 80. `verify/workstation.sh` akzeptiert einen `hardening_index` größer oder gleich diesem Schwellenwert.                                                                                                                                                                                                                                                                                                                                                         |
| Journale   | Installationsjournale liegen unter `<source>/logs/install-YYYYMMDD-HHMMSS-user/`. Sicherheitsjournale liegen unter `/opt/high-fortress-user/cron/security_logs/`. Der Journald-Speicher ist persistent.                                                                                                                                                                                                                                                                               |
| Pakete     | Die Snaps Firefox und Thunderbird werden entfernt. `snapd` bleibt. Das Paket `firefox` wird gehalten. Auf amd64 wird die Architektur i386 aktiviert. Steam wird von diesem Programm nicht installiert.                                                                                                                                                                                                                                                                                |

## Alarm-E-Mails

Post geht nur ab, wenn `HF_MAIL_ALERTS=1` ist, `WATCHDOG_MAIL` gesetzt ist und `/opt/high-fortress-user/cron/bin/send.sh` ausführbar ist. Eine saubere Kontrolle sendet keine Post. Wenn eine Journalzeile unbekannt ist, starten Sie den Befehl nicht. Behalten Sie die Post.

### AIDE

Die Nachricht enthält die Zusammenfassungszeile und einen Auszug des Journals, dann den Hinweis und den Befehlsblock. Der Journalpfad in der Post ist die echte Datei. Die Form ist `/opt/high-fortress-user/cron/security_logs/aide-YYYYMMDD-HHMMSS.log`.

```bash
sudo bash /opt/high-fortress-user/bin/aide-refresh-db.sh
```

Der Befehl baut die AIDE-Basis aus der aktuellen Platte neu auf. Die Erfolgszeile ist `Base de référence AIDE enregistrée.`

### chkrootkit

Die Nachricht enthält die Zusammenfassung und den Journalauszug, dann den Hinweis und den Befehl. Das Beispiel unten zeigt die Form. Die Post enthält den echten Pfad.

```bash
sudo bash /opt/high-fortress-user/bin/chkrootkit-ignore-log.sh '/opt/high-fortress-user/cron/security_logs/chkrootkit-YYYYMMDD-HHMMSS.log'
```

Der Befehl speichert die Zeilen dieses Journals in `/opt/high-fortress-user/cron/chkrootkit.local.ignore`. Die Erfolgszeile ist `Aucune nouvelle détection à enregistrer.`, wenn nichts Neues hinzukommt, oder `N détection(s) enregistrée(s) dans /opt/high-fortress-user/cron/chkrootkit.local.ignore`.

### debsums

Die Nachricht enthält die Zusammenfassung und den Journalauszug, dann den Hinweis und den Befehl. Das Beispiel unten zeigt die Form. Die Post enthält den echten Pfad.

```bash
sudo bash /opt/high-fortress-user/bin/debsums-ignore-log.sh '/opt/high-fortress-user/cron/security_logs/debsums-YYYYMMDD-HHMMSS.log'
```

Der Befehl speichert die Zeilen dieses Journals in `/opt/high-fortress-user/cron/debsums.local.ignore`. Die Erfolgszeile ist `Aucune nouvelle détection à enregistrer.` oder `N détection(s) enregistrée(s) dans /opt/high-fortress-user/cron/debsums.local.ignore`. Eine Zeile für `/var/lib/rkhunter/db/mirrors.dat` wird vor der Post nur entfernt, wenn ihr aktueller SHA-256 gleich `/opt/high-fortress-user/cron/rkhunter-mirrors.sha256` ist. Jeder andere Inhalt bleibt in der Post. Ignorieren Sie nicht die ganze Datei.

### ClamAV beim Zugriff

Die Nachricht enthält die Signatur, den Dateinamen, den Ursprungspfad und den Quarantänepfad, dann den Hinweis und einen `sudo ls`-Befehl. Der Befehl wird für die in der Post genannte Quarantänedatei gebaut. Eine Datei, deren Basisname auf `.clamav-quarantine-lock.*` passt, sendet keine Post. Das Skript endet mit 0 vor dem Journal und vor `log_alert`.

```bash
sudo ls -la -- /var/lib/clamav/quarantine/<file>
```

Das Beispiel zeigt die Form. Die Post enthält den echten Pfad, quotiert. Der Befehl listet diese Datei und legt sie nicht zurück. `ls` gibt den Verzeichniseintrag aus. Es gibt keine Erfolgszeile des Installationsprogramms.

### ClamAV-Startprüfung

Die Nachricht enthält die Zusammenfassung und den Journalauszug. Diese Post fügt keinen Befehlsblock hinzu. Die Journalform ist `/opt/high-fortress-user/cron/security_logs/clamav-YYYYMMDD-HHMMSS.log`.

### rkhunter

Die Nachricht enthält die Zusammenfassung und den Journalauszug. Diese Post fügt keinen Befehlsblock hinzu. Eine abweichende Prüfsumme fügt die Zeile `mirrors.dat modifié hors rkhunter --update` hinzu. Diese Zeile ist kein Befehl. Die Journalform ist `/opt/high-fortress-user/cron/security_logs/rkhunter-YYYYMMDD-HHMMSS.log`.

## Befehle nach der Installation

Starten Sie diese Befehle aus dem Quellverzeichnis (`/opt/high-fortress-user/src` nach dem Curl-Installer, oder das Klonverzeichnis).

### hf check

```bash
sudo ./hf check
```

Prüft `global.conf` und `secrets.conf`. Die Erfolgszeile ist `Configuration conforme`. `secrets.conf` hat Modus `600`, daher ist `sudo` zum Lesen erforderlich.

### hf run

```bash
sudo ./hf run
```

Startet die Installation aus den vorbereiteten Dateien. Das Installationsprogramm startet nicht, wenn die Prüfung nicht besteht.

### verify/alerts.sh

```bash
sudo bash verify/alerts.sh
```

Prüft den Start-Timer, ClamAV beim Zugriff und den Mail-Pfad. Ohne `--no-send` geht eine Sonde ab, wenn die Alarme eingeschaltet sind. Der Betreff endet mit `Contrôle`. Die Erfolgszeile ist `Résultat : OK`.

```bash
sudo bash verify/alerts.sh --no-send
```

Dieselbe Prüfung ohne die Sonde.

### verify/workstation.sh

```bash
sudo bash verify/workstation.sh "$PWD"
```

Startet die Arbeitsplatzprüfung. Die Schlusszeile hat die Form `Check : N OK / N WARN / N FAIL`.

### hf lynis

```bash
sudo ./hf lynis
```

Startet `lynis audit system --quick --no-colors` und schreibt den Bericht unter `<source>/logs/lynis-<stamp>/`.

### AIDE-Basis

```bash
sudo bash /opt/high-fortress-user/bin/aide-refresh-db.sh
```

Baut `/var/lib/aide/aide.db` neu. Die Erfolgszeile ist `Base de référence AIDE enregistrée.`

### rkhunter-Spiegelstempel

```bash
sudo bash /opt/high-fortress-user/cron/bin/record-mirrors.sh save
```

Schreibt den SHA-256 von `/var/lib/rkhunter/db/mirrors.dat` nach `/opt/high-fortress-user/cron/rkhunter-mirrors.sha256` mit Modus `600`. `rkhunter.sh` speichert diesen Stempel nur, wenn `rkhunter --update` 0 oder 2 zurückgibt.

## Ausführliche Seiten

| Thema                          | Seite                                |
| ------------------------------ | ------------------------------------ |
| Allgemeine und Dienstvariablen | [configuration.md](configuration.md) |
| Überwachungswerkzeuge          | [surveillance.md](surveillance.md)   |
| Installierter Baum             | [architecture.md](architecture.md)   |
| Installierte Dateien           | [files.md](files.md)                 |
| Journale                       | [logs.md](logs.md)                   |
