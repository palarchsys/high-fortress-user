# High-Fortress User

## Beschreibung

High-Fortress User bereitet einen Ubuntu-Arbeitsplatz 26.04 oder neuer vor. Es installiert den lokalen DNS-Resolver, die Firewall und die Sicherheitskontrollen.

Das bereits angelegte Ubuntu-Konto auf der Maschine wird nicht ersetzt. Das Installationsprogramm legt kein zweites Konto an.

`secrets.conf` bleibt auf der Maschine. Kopieren Sie es nicht in eine Nachricht, ein Ticket oder ein Repository.

## Bevor Sie beginnen

### System

Ubuntu 26.04 oder neuer. Eine Neuinstallation ist vorzuziehen. Benutzen Sie eine lokale Konsole oder die bereits geöffnete grafische Sitzung. Die Maschine braucht Internetzugang.

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

`install.sh` installiert außerdem `curl`, `ca-certificates` und `tar`, lädt den Zweig `main` und schreibt die Quellen nach `/opt/high-fortress-user/src`. Danach startet es `scripts/configure.sh`. Wenn `global.conf` bereits `HF_CONFIG_PREPARED=1` enthält, `secrets.conf` existiert und `scripts/configure.sh --check` besteht, startet es stattdessen `scripts/run.sh`.

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
| From             | Eine E-Mail-Adresse. `HF_WATCHDOG_MAIL` erhält dieselbe Adresse.                                                                                                            | Nichts beim ersten Lauf.                                                       |
| Mode test        | `0` oder `1`.                                                                                                                                                            | Der aktuelle Wert von `HF_MODE_TEST`. Der mitgelieferte Vorgabewert ist `[1]`.    |

Wenn die Alarme eingeschaltet sind, muss `swaks` ein SMTP-`250` erhalten. Die Erfolgszeile ist `Essai d'envoi accepté.` `HF_MAIL_ALERTS` wird `1`. Wenn die Alarme aus sind, ist die Erfolgszeile `Alertes e-mail coupées. Les contrôles partiront sans envoi.` und die Mail-Variablen werden geleert.

Werte, die nicht gefragt werden, kommen aus `hfu_set_config_default` und aus der mitgelieferten `global.conf`. Sie stehen in [configuration.md](configuration.md). Es wird kein Zufallskennwort erzeugt.

## Installierte Software und Dienste

| Name                                            | Herkunft                                                                                | Rolle                                                                                                                     |
| ----------------------------------------------- | --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| openssh-server                                  | Ubuntu archive                                                                          | SSH-Server. Root-Anmeldung ist abgelehnt. Kennwortanmeldung bleibt eingeschaltet.                                         |
| ufw                                             | Ubuntu archive                                                                          | Host-Firewall.                                                                                                            |
| usbguard, usbguard-notifier                     | Ubuntu archive                                                                          | Erlaubt bereits angeschlossene Geräte sowie Tastaturen, Mäuse und Hubs. Ein neues Speichergerät wartet auf eine Bestätigung auf der Arbeitsfläche. |
| fail2ban                                        | Ubuntu archive                                                                          | Sperrt wiederholte Anmeldefehlschläge.                                                                                    |
| auditd                                          | Ubuntu archive                                                                          | Schreibt Audit-Regeln für ausgewählte Pfade.                                                                              |
| rkhunter                                        | Ubuntu archive                                                                          | Rootkit- und Dateieigenschaftsprüfung.                                                                                    |
| chkrootkit                                      | Ubuntu archive                                                                          | Rootkit-Prüfung. Die Binärdatei ist `/usr/sbin/chkrootkit`.                                                               |
| clamav                                          | Ubuntu archive                                                                          | Prüfung beim Zugriff und Prüfung beim Start.                                                                              |
| crowdsec                                        | https://packagecloud.io/crowdsec/crowdsec/any any main                                  | Lokale Sicherheitsentscheidungen.                                                                                         |
| debsums                                         | Ubuntu archive                                                                          | Prüfsummen der Paketdateien.                                                                                              |
| unbound                                         | Ubuntu archive                                                                          | Lokaler DNS-Resolver auf `127.0.0.1` und `::1`, Port 53.                                                                  |
| apparmor                                        | Ubuntu archive, plus `service/apparmor/userns.sh`                                       | Distributionsprofile. `service/apparmor/userns.sh` entfernt ein hfu-Profil, das nicht geliefert wird.    |
| aide                                            | Ubuntu archive                                                                          | Dateiintegritätsdatenbank `/var/lib/aide/aide.db`.                                                                        |
| unattended-upgrades                             | Ubuntu archive                                                                          | Sicherheitsherkünfte. `Automatic-Reboot` ist `false`.                                                                     |
| postfix                                         | Ubuntu archive, only when `HF_MAIL_ALERTS=1`                                            | Sendet die Alarmpost.                                                                                                     |
| lynis                                           | https://packages.cisofy.com/community/lynis/deb/ stable main                            | Härtungsaudit. Der Schlüssel ist `https://packages.cisofy.com/keys/cisofy-software-public.key`.                           |
| ubuntu-pro-client                               | Ubuntu archive                                                                          | Bindet das Ubuntu-Pro-Token an.                                                                                           |
| acct, sysstat, libpam-pwquality                 | Ubuntu archive                                                                          | Prozessabrechnung, Aktivitätsstatistik, Kennwortqualität.                                                                 |
| rng-tools-debian, haveged                       | Ubuntu archive                                                                          | Entropiequellen.                                                                                                          |
| apt-listchanges, needrestart, apt-show-versions | Ubuntu archive                                                                          | Paketänderungshinweise und Neustartprüfungen.                                                                             |

## Was die Maschine nach der Installation tut

| Thema      | Verhalten                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Firewall   | `ufw default deny incoming`, `ufw default allow outgoing`, `ufw default allow routed`. Loopback ist in beide Richtungen erlaubt. SSH auf dem erkannten Port ist auf jedes direkt verbundene Präfix begrenzt. Wenn kein Präfix aktiv ist, bleibt die Begrenzung von jeder Quelle.                                                                                                                                                                                                                                                                                              |
| DNS        | Unbound lauscht auf `127.0.0.1` und `::1`. systemd-resolved und NetworkManager zeigen auf diesen Resolver. IPv6-DNS bleibt eingeschaltet (`do-ip6: yes`).                                                                                                                                                                                                                                                                                                                             |
| SSH        | `PermitRootLogin no`. `PasswordAuthentication yes`. `PubkeyAuthentication yes`. Banner `/etc/ssh/sshd_banner`. `MaxAuthTries 4`. `AllowTcpForwarding no`. `AllowAgentForwarding no`.                                                                                                                                                                                                                                                                                                                                                      |
| Kernel     | `/etc/sysctl.d/90-high-fortress-user.conf` wird nach `/etc/sysctl.d/99-zzz-high-fortress-user.conf` kopiert. IPv6 bleibt eingeschaltet. IPv6-Redirects und Source-Routing werden abgelehnt. User-Namespaces bleiben eingeschaltet. `dccp`, `sctp`, `rds` und `tipc` werden gesperrt. Ungenutzte Dateisysteme werden gesperrt. Core-Dumps stehen auf 0. `HFU_PAM_PASSWORD_MIN_LENGTH` ist 12.                                                                                                     |
| AppArmor   | `service/apparmor/userns.sh` entfernt ein hfu-Profil, das nicht geliefert wird.                                                                                                                                                                                                                                                                                                      |
| Kontrollen | `hfu-boot-chain.timer` startet `hfu-boot-chain.service`, wenn `multi-user.target` erreicht ist (`OnBootSec=0`, `Persistent=false`). Die Kette startet `hfu-boot-scan.service`, dann `hfu-idle-scan.service`, dann `hfu-reboot-notice.service`. Der Startlauf startet AIDE, rkhunter, chkrootkit, ClamAV und debsums. `hfu-hourly-scan.timer` startet AIDE, rkhunter, chkrootkit und debsums eine Stunde nach dem Boot, dann jede Stunde (`OnBootSec=1h`, `OnUnitActiveSec=1h`, `Persistent=false`). `Nice` ist `HF_WATCHDOG_LIMIT_NICE` (19), `IOSchedulingClass=idle`, `CPUQuota` ist `HF_WATCHDOG_CPU_LIMIT` mal der CPU-Anzahl, also 50 für 50 % der ganzen Maschine. `/etc/cron.d/high-fortress-user` enthält nur `SHELL` und `PATH`. Die Benutzer-Crontab wird nicht geändert. Post geht nur ab, wenn eine Kontrolle etwas findet und `HF_MAIL_ALERTS=1` ist. `hfu-idle-scan.timer` wiederholt die verzögerte Prüfung jede Stunde. `hfu-reboot-notice.timer` wiederholt den Hinweis alle 6 Stunden und sendet Post, wenn ein Neustart sinnvoll ist und kein Spiel läuft. Die Regeln stehen in [surveillance.md](surveillance.md). |
| Lynis      | `HF_LYNIS_MIN_SCORE` ist 80. `verify/workstation.sh` akzeptiert einen `hardening_index` größer oder gleich diesem Schwellenwert.                                                                                                                                                                                                                                                                                                                                                         |
| Journale   | Installationsjournale liegen unter `<source>/logs/install-YYYYMMDD-HHMMSS-user/`. Sicherheitsjournale liegen unter `/opt/high-fortress-user/cron/security_logs/`. Der Journald-Speicher ist persistent.                                                                                                                                                                                                                                                                               |
| Pakete     | Auf amd64 wird die Architektur i386 aktiviert. CUPS wird zu Beginn der Installation entfernt. |
| USB          | Geräte, die beim configure angeschlossen sind, bleiben erlaubt. Schnittstellenklasse `03` und Klasse `09` bleiben erlaubt. Ein neues Speichergerät bleibt blockiert, bis Sie es auf der Arbeitsfläche annehmen. Das Modul `usb-storage` bleibt verfügbar. |

## Alarm-E-Mails

Post geht nur ab, wenn `HF_MAIL_ALERTS=1` ist, `HF_WATCHDOG_MAIL` gesetzt ist und `/opt/high-fortress-user/cron/bin/send.sh` ausführbar ist. Eine saubere Kontrolle sendet keine Post. Wenn eine Journalzeile unbekannt ist, starten Sie den Befehl nicht. Behalten Sie die Post.

Eine Prüfung, die vor ihrem normalen Ende stoppt, sendet Post.

Die Post nennt die Prüfung.

Die Post nennt das Signal oder den Code.

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

Ein bestätigter Fund verschiebt die Datei und hängt stattdessen den Wiederherstellungsbefehl an.

Der Ignorierbefehl bleibt nur, wenn keine bestätigte Datei verschoben wurde.

### debsums

Die Nachricht enthält die Zusammenfassung und den Journalauszug. Sie fügt keinen Befehlsblock hinzu. Die Prüfung installiert jedes noch genannte Paket mit `apt-get install --reinstall` neu. Die Post nennt jedes wiederhergestellte Paket. Die Erfolgszeile ist `La somme correspond.`

Ein Paket, dessen Summe verschieden bleibt oder dessen Neuinstallation fehlschlägt, bleibt in der Post.

Eine Zeile für `/var/lib/rkhunter/db/mirrors.dat` wird vor dieser Neuinstallation nur entfernt, wenn ihr aktueller SHA-256 gleich `/opt/high-fortress-user/cron/rkhunter-mirrors.sha256` ist.

Eine geänderte Zeile unter `/usr/lib/*/perl-base/unicore/` aus dem Paket `perl-base` wird vor dieser Neuinstallation entfernt.

Die von Ubuntu gelieferte Datei entspricht nicht der Summe dieses Pakets.

### ClamAV beim Zugriff

Die Nachricht enthält die Signatur, den Dateinamen, den Ursprungspfad und den Quarantänepfad, dann den Hinweis und einen Wiederherstellungsbefehl je verschobener Datei.

Dasselbe Journal nennt die Uhrzeit, die Art des Funds, die ausgeführten Aktionen und eine kurze Empfehlung. Eine Datei, deren Basisname auf `.clamav-quarantine-lock.*` passt, sendet keine Post. Das Skript endet mit 0 vor dem Journal und vor `hf_log_alert`.

```bash
sudo bash /opt/high-fortress-user/bin/quarantine-restore.sh <id>
```

Das Beispiel zeigt die Form. Die Post enthält die echte Kennung. Der Befehl legt diese Datei an ihren Ursprungsort zurück. Die Erfolgszeile ist `fichier remis en place`.

Das Register ist `/opt/high-fortress-user/cron/quarantine.registry`.

### ClamAV-Startprüfung

Die Nachricht enthält die Zusammenfassung und den Journalauszug.

Wenn eine Datei verschoben wurde, fügt die Post einen Wiederherstellungsbefehl je Datei hinzu.

Der Befehl ist derselbe wie in der Zugriffspost.

Die Journalform ist `/opt/high-fortress-user/cron/security_logs/clamav-YYYYMMDD-HHMMSS.log`.

Eine unlesbare Datei ohne Zeile `FOUND` sendet keine Post.

Die Zeilen `Known viruses` und `Infected files` werden nicht in die Post übernommen.

Ein durch ein Signal gestoppter `clamscan` sendet Post.

Die Post nennt das Signal und jede ungelesene Datei.

Die übrigen Dateien des Laufs werden geprüft.

Zwei Abstürze nacheinander stoppen den ClamAV-Lauf.

Die Post sagt dann, dass die restlichen Dateien nicht gelesen wurden.

### Verzögerte ClamAV-Prüfung

Die Nachricht enthält die Zusammenfassung und den Journalauszug.

Wenn eine Datei verschoben wurde, fügt die Post einen Wiederherstellungsbefehl je Datei hinzu.

Der Befehl ist derselbe wie in der Zugriffspost.

Eine Signatur und ein Pfad, die schon in `/opt/high-fortress-user/cron/scan-skip.seen` stehen, senden keine Post mehr.

Ein durch ein Signal gestoppter `clamscan` sendet Post.

Die Post nennt das Signal und jede ungelesene Datei.

Die übrigen Dateien des Laufs werden geprüft.

Zwei Abstürze nacheinander stoppen den ClamAV-Lauf.

Die Post sagt dann, dass die restlichen Dateien nicht gelesen wurden.

Der Stempel bleibt stehen.

Die Journalform ist `/opt/high-fortress-user/cron/security_logs/idle-scan-YYYYMMDD-HHMMSS.log`.

### rkhunter

Die Warnpost enthält die Zusammenfassung und den Journalauszug, dann den Hinweis und den Befehlsblock. Die Post `mirrors.dat modifié hors rkhunter --update` fügt diesen Block nicht hinzu. Eine Fehlerpost fügt ihn ebenfalls nicht hinzu. Die Journalform ist `/opt/high-fortress-user/cron/security_logs/rkhunter-YYYYMMDD-HHMMSS.log`.

```bash
sudo bash /opt/high-fortress-user/bin/rkhunter-refresh-db.sh
```

Der Befehl berechnet die rkhunter-Eigenschaftsbasis aus der aktuellen Platte neu. Die Erfolgszeile ist `Base de propriétés rkhunter enregistrée.`

Ein bestätigter Fund verschiebt die Datei und hängt stattdessen den Wiederherstellungsbefehl an.

Der Neuberechnungsbefehl bleibt nur, wenn keine bestätigte Datei verschoben wurde.

Dateien unter `/dev/shm` und der Socket `/dev/log` sind in `rkhunter.conf.local` erlaubt.

Sie erzeugen nicht die Warnung `Suspicious file types found in /dev`.

Der Auszug behält die Warnzeile und die folgenden Pfade.

### Neustart-Hinweis

Die Nachricht ist `Un redémarrage est utile. La machine n'a pas été redémarrée.`

Diese Post fügt keinen Befehlsblock hinzu.

Dieselbe Paketmenge sendet keine Post mehr.

Ein laufendes Spiel überspringt die Post und lässt den Stempel unverändert.

Das Skript startet die Maschine nicht neu.

Die Journalform ist `/opt/high-fortress-user/cron/security_logs/reboot-notice-YYYYMMDD-HHMMSS.log`.

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

Prüft den Ketten-Timer, den verzögerten Timer, ClamAV beim Zugriff und den Mail-Pfad. Ohne `--no-send` geht eine Sonde ab, wenn die Alarme eingeschaltet sind. Der Betreff endet mit `Contrôle`. Die Erfolgszeile ist `Résultat : OK`.

```bash
sudo bash verify/alerts.sh --no-send
```

Dieselbe Prüfung ohne die Sonde.

### verify/workstation.sh

```bash
sudo bash verify/workstation.sh "$PWD"
```

Startet die Arbeitsplatzprüfung. Die Schlusszeile hat die Form `Check : N OK / N WARN / N FAIL`.

Derselbe Lauf prüft die SSH-Weiterleitung, die SSH-Firewallregel, USBGuard, die sudo-Frist und `hfu-reboot-notice.timer`.

### Prüfung nach dem Start

```bash
sudo bash /opt/high-fortress-user/bin/boot-check.sh
```

Prüft die Sicherheitsdienste des Starts und die drei Läufe dieser Sitzung.

Die Erfolgszeile ist `Contrôle de démarrage : OK`.

Ein noch laufender Lauf zeigt `Contrôle de démarrage : en cours` und endet mit Code 1.

Eine Abweichung zeigt `Contrôle de démarrage : écarts` und endet mit Code 1.

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

### Vom Scan ausgeschlossene Pfade

```bash
sudo bash /opt/high-fortress-user/bin/scan-skip.sh list
sudo bash /opt/high-fortress-user/bin/scan-skip.sh add /var/jeux/exemple
sudo bash /opt/high-fortress-user/bin/scan-skip.sh del /var/jeux/exemple
```

Die Listendatei ist `/opt/high-fortress-user/src/config/clamav/scan-skip.paths`.

Eine schon vorhandene Liste bleibt stehen, wenn das Installationsprogramm erneut läuft.

Eine Liste, die noch in `/opt/high-fortress-user/cron/scan-skip.paths` liegt, wird einmal kopiert, wenn die neue Datei noch die Vorlage ist.

| Aktion | Angezeigte Zeile |
| --- | --- |
| `list` | ein akzeptierter Pfad je Zeile |
| `add` | `Chemin ajouté : <path>` |
| schon vorhanden | `Ce chemin est déjà exclu : <path>` |
| `del` | `Chemin retiré : <path>` |
| abgelehnt | `Chemin refusé : <path>` |

Ein abgelehnter Pfad lässt die Datei unverändert.

Der Befehl schreibt `/etc/clamav/clamd.conf` neu.

Er startet `clamav-daemon` neu, dann `clamav-clamonacc.service` oder `clamonacc.service`, wenn der Ausschlussblock sich ändert.

Akzeptierte Pfade, die gelieferte Liste und die Ablehnungen stehen in [surveillance.md](surveillance.md).

## Ausführliche Seiten

| Thema                          | Seite                                |
| ------------------------------ | ------------------------------------ |
| Allgemeine und Dienstvariablen | [configuration.md](configuration.md) |
| Überwachungswerkzeuge          | [surveillance.md](surveillance.md)   |
| Installierter Baum             | [architecture.md](architecture.md)   |
| Installierte Dateien           | [files.md](files.md)                 |
| Journale                       | [logs.md](logs.md)                   |
