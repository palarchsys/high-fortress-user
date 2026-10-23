[Vollständiges README](README.md)

# Überwachung

Eine Journalzeile in einer Alarmpost bleibt auf einer Zeile.

Die Alarmpost ist 400px bis 800px breit und folgt dem Nachrichtenbereich zwischen diesen Breiten.

Die Alarmpost füllt mindestens die Höhe des Nachrichtenbereichs.

## AIDE

| Dienst, der überwacht   | Zonen                                               | Was als Alarm geht                                                       | Befehl der Post                                            |
| ----------------------- | --------------------------------------------------- | ------------------------------------------------------------------------ | ---------------------------------------------------------- |
| aide.sh in boot-scan.sh | /etc/aide/aide.conf, database /var/lib/aide/aide.db | Änderungen, oder ein Code ungleich null, der kein sauberes Ergebnis ist. | `sudo bash /opt/high-fortress-user/bin/aide-refresh-db.sh` |

Flüchtige Pfade, Journale, Caches und die Cron-Berichtverzeichnisse sind in `config/aide/aide.conf` ausgeschlossen, damit die Basis nicht von diesen Dateien neu geschrieben wird.

Dateien `*.stamp`, `integrity.sha256` und `rkhunter-mirrors.sha256` im Cron-Verzeichnis des Produkts sind ausgeschlossen.

Die Datei `/etc/crowdsec/hub/.index.json` ist ausgeschlossen.

Sie ist der Katalog, den `cscli hub update` herunterlädt.

Die anderen Dateien unter `/etc/crowdsec/` werden überwacht.

Der Kontenblock wird nach `!/home/` angehängt.

Die letzte passende Regel gilt.

Die überwachten Pfade sind `.ssh/authorized_keys`, `.bashrc`, `.profile`, `.bash_profile`, `.config/autostart` und `.config/systemd/user` des Arbeitsplatzkontos.

`.ssh/known_hosts` und `.ssh/known_hosts.old` sind ausgeschlossen.

## rkhunter

| Dienst, der überwacht       | Zonen                                              | Was als Alarm geht                                                                         | Befehl der Post    |
| --------------------------- | -------------------------------------------------- | ------------------------------------------------------------------------------------------ | ------------------ |
| rkhunter.sh in boot-scan.sh | Prüfumfang des Pakets, plus die Eigenschaftsbasis. | Warnungen, ein fehlgeschlagenes Update, oder `mirrors.dat modifié hors rkhunter --update`. | `sudo bash /opt/high-fortress-user/bin/rkhunter-refresh-db.sh` |

Der Neuberechnungsbefehl steht in der Warnpost, wenn keine bestätigte Datei verschoben wurde. Die Stempelzeile und ein fehlgeschlagenes Update fügen ihn nicht hinzu.

`/var/lib/rkhunter/db/mirrors.dat` wird nicht als Datei ignoriert. Der Stempel `/opt/high-fortress-user/cron/rkhunter-mirrors.sha256` wird nur geschrieben, wenn `rkhunter --update` 0 oder 2 zurückgibt. Ein anderer Hash ist ein Alarm. Die Prüfung läuft vor dem nächsten `--update`.

Dateien unter `/dev/shm` und der Socket `/dev/log` sind erlaubt.

Sie erzeugen nicht die Warnung `Suspicious file types found in /dev`.

Eine verbleibende Zeile, die `INFECTED` enthält, oder `Rootkit` und einen absoluten Pfad einer regulären Datei, ist ein bestätigter Fund.

Eine Zeile, die `Rootkit Hunter` enthält, wird übersprungen, außer sie enthält auch `INFECTED`.

Diese Datei geht nach `/var/lib/clamav/quarantine`.

Ein Halter, der nicht geschützt ist, erhält `TERM`.

Geschützte Halter sind pid 1, uid 0, ein leerer Name, `systemd`, `sshd`, `unbound`, `fail2ban` und `gamescope`.

Dieselbe Regel gilt für `/etc/passwd`, `/etc/shadow`, `/etc/sudoers`, `/etc/ssh/sshd_config`, `/etc/ufw/ufw.conf`, `/usr/bin/sudo`, `/usr/bin/passwd` und `/usr/sbin/sshd`.

Ein geschützter Pfad oder Halter bleibt an seinem Ort.

Die Post sagt `non mis en quarantaine`.

Jede verschobene Datei fügt einen Wiederherstellungsbefehl hinzu.

```bash
sudo bash /opt/high-fortress-user/bin/quarantine-restore.sh <id>
```

Das Register ist `/opt/high-fortress-user/cron/quarantine.registry`.

Die Erfolgszeile ist `fichier remis en place`.

Eine Warnung, die nicht bestätigt ist, bleibt eine Post.

## chkrootkit

| Dienst, der überwacht         | Zonen                   | Was als Alarm geht                                 | Befehl der Post                                                              |
| ----------------------------- | ----------------------- | -------------------------------------------------- | ---------------------------------------------------------------------------- |
| chkrootkit.sh in boot-scan.sh | /usr/sbin/chkrootkit -q | Jede verbleibende Ausgabe nach den Ignorierlisten. | `sudo bash /opt/high-fortress-user/bin/chkrootkit-ignore-log.sh '<journal>'` |

Bekannte Zeilen stehen in `src/config/chkrootkit/patterns.ignore` und in `cron/chkrootkit.local.ignore`.

Die lokale Datei wird nur durch den Befehl aus der Post gefüllt, und nur für Zeilen, die Sie erkennen.

Ein bestätigter Fund nutzt dieselbe Verschiebung und dieselbe `TERM`-Regel wie rkhunter.

Der Ignorierbefehl wird nur angehängt, wenn keine bestätigte Datei verschoben wurde.

## ClamAV beim Zugriff

| Dienst, der überwacht           | Zonen                  | Was als Alarm geht                              | Befehl der Post                    |
| ------------------------------- | ---------------------- | ----------------------------------------------- | ---------------------------------- |
| clamonacc, then clamav-event.sh | XDG-Ordner, /tmp, /var/tmp, /opt. | Ein echter Fund. Sperrdateien alarmieren nicht. | `sudo bash /opt/high-fortress-user/bin/quarantine-restore.sh <id>` |

| Ausschluss | Regel |
| --- | --- |
| `scan-skip.paths` | Nur akzeptierte Pfade. |
| Benutzer `clamav` | `OnAccessExcludeUname clamav` |
| root | `OnAccessExcludeRootUID yes` |
| Größe | Dateien über 25M. |
| /var/lib/snapd, /snap | Fester Ausschluss. |
| /var/lib/clamav/quarantine, /var/lib/clamav/tmp | Fester Ausschluss. |
| /opt/high-fortress-user, /var/log | Fester Ausschluss. |

Die gelieferte Datei listet:

- `$HOME/.cache`
- `$HOME/snap`
- `/var/jeux`

Ein Pfad wird unter dem Home des Benutzers des Arbeitsplatzes akzeptiert, unterhalb dieses Homes.

Ein Pfad wird unter `/var/jeux` akzeptiert, einschließlich `/var/jeux`.

| Ablehnung | Pfade |
| --- | --- |
| Systemwurzeln | `/`, `/home`, `/opt`, `/tmp`, `/etc`, `/usr`, `/var`, `/boot`, `/root` |
| ganzes Home | `/home/<user>` |
| Zugriffspfade | Downloads, Desktop |
| Elternverzeichnis | ein Verzeichnis, das Downloads oder Desktop enthält |
| sonst | ein Pfad außerhalb dieses Homes und außerhalb von `/var/jeux` |

Eine abgelehnte Zeile wird ignoriert.

Die Zeile wird an `/opt/high-fortress-user/cron/security_logs/scan-skip.log` angehängt.

`/var/jeux` ist ein leeres Verzeichnis, Modus 750, Eigentümer ist der Benutzer des Arbeitsplatzes.

Es ist kein separates Konto.

`.clamav-quarantine-lock.*` ist eine Verschiebesperre, keine Schadsoftware.

`clamav-event.sh` endet mit 0 vor `hf_log_alert`.

`scan-skip.sh` ändert die Liste.

Die Befehle stehen im README.

Dieselbe Neuschreibung läuft am Anfang von `boot-scan.sh`.

Eine schon vorhandene `scan-skip.paths` bleibt stehen, wenn das Installationsprogramm erneut läuft.

Die Neuschreibung ersetzt die Zeilen `OnAccessExcludePath` zwischen `# BEGIN High-Fortress User scan-skip` und `# END High-Fortress User scan-skip`.

Die Neuschreibung startet `clamav-daemon` neu, dann `clamav-clamonacc.service` oder `clamonacc.service`, wenn dieser Block sich ändert.

Ein verborgener Pfad erhält `ALLOWHIDDENDIR` in `/etc/rkhunter.conf.local`, wenn die Zeile fehlt.

Vorhandene rkhunter-Zeilen bleiben.

## ClamAV-Startprüfung

| Dienst, der überwacht     | Zonen             | Was als Alarm geht                              | Befehl der Post    |
| ------------------------- | ----------------- | ----------------------------------------------- | ------------------ |
| clamav.sh in boot-scan.sh | /home, /opt, /tmp | Infektionen. Eine saubere Prüfung bleibt still. | `sudo bash /opt/high-fortress-user/bin/quarantine-restore.sh <id>` |

Die Prüfung schneidet `OnAccessExcludePath`-Einträge und die akzeptierten Pfade aus `scan-skip.paths` ab.

Die Prüfung schneidet auch `proc`, `sys`, `dev`, `var/lib/docker`, `var/lib/libvirt`, `libvirt` und `snap-private-tmp` ab.

Dateien über 25M bleiben außen vor.

Die Dateiliste steht unter `/run/high-fortress-user`.

Wenn `/run/clamav/clamd.ctl` existiert, setzt der Lauf `HF_CLAM_MODE=daemon`.

Sonst nutzt er `clamscan`.

Die Unit deckelt diesen Lauf auf 50 % der ganzen Maschine.

Die Zahl wird beim Einrichten von cron geschrieben.

Eine spätere Änderung der CPU-Anzahl verlangt diesen Schritt erneut.

`hfu-boot-chain.service` startet diesen Lauf, dann die verzögerte Prüfung, dann den Neustart-Hinweis.

Die Kette startet, wenn `multi-user.target` erreicht ist.

Ein fehlgeschlagener Lauf hält den nächsten nicht auf.

Eine unlesbare Datei ohne Zeile `FOUND` sendet keine Post.

Ein durch ein Signal gestoppter `clamscan` sendet Post.

Die Post nennt das Signal und jede ungelesene Datei.

Die übrigen Dateien des Laufs werden geprüft.

Zwei Abstürze nacheinander stoppen den ClamAV-Lauf.

Die Post sagt dann, dass die restlichen Dateien nicht gelesen wurden.

## Periodische ClamAV-Prüfung

| Dienst, der überwacht | Zonen | Was als Alarm geht | Befehl der Post |
| --- | --- | --- | --- |
| clamav.sh in hfu-periodic-scan.timer | /home, /opt, /tmp, mit denselben Schnitten wie der Startlauf. | Infektionen. Ein sauberer Lauf bleibt still. | `sudo bash /opt/high-fortress-user/bin/quarantine-restore.sh <id>` |

Der Timer ist `OnBootSec=2h` und `OnUnitActiveSec=2h`, mit `Persistent=false`.

`Nice` ist 19, `IOSchedulingClass` ist `idle`, und `CPUQuota` ist dieselbe Quote wie der Startlauf.

Ein laufendes `lutris`, `heroic` oder `gamescope` überspringt den Lauf.

`/run/high-fortress-user/clamav.lock` hält einen zweiten Lauf an.

## Stündliche Prüfung

| Dienst, der überwacht | Zonen | Was als Alarm geht | Befehl der Post |
| --- | --- | --- | --- |
| hourly-scan.sh in hfu-hourly-scan.timer | AIDE, dann rkhunter, dann chkrootkit, dann debsums. Dieselben Kontrollen wie der Startlauf. | Dieselben Funde wie jede dieser Startkontrollen. Ein sauberer Lauf bleibt still. | Der Postbefehl dieser Kontrolle. |

Der Timer ist `OnBootSec=1h` und `OnUnitActiveSec=1h`, mit `Persistent=false`.

`Nice` ist 19, `IOSchedulingClass` ist `idle`, und `CPUQuota` ist dieselbe Quote wie der Startlauf.

Der Startlauf startet diese vier Kontrollen.

## Verzögerte ClamAV-Prüfung

| Dienst, der prüft                   | Zonen                                                                                                      | Was alarmiert wird                                                                                                              | Postbefehl               |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| idle-scan.sh in hfu-idle-scan.timer | Akzeptierte Pfade, außer `.cache` und `snap`. | Ein neuer Fund. Ein bekanntes Paar in `scan-skip.seen` sendet keine Post mehr. | `sudo bash /opt/high-fortress-user/bin/quarantine-restore.sh <id>` |

| Einstellung | Wert |
| --- | --- |
| Timer | `OnUnitActiveSec=1h`, `Persistent=false` |
| Grenzen | `Nice` 19, `IOSchedulingClass=idle`, `CPUQuota` 50 % der ganzen Maschine |
| Warten | `lutris`, `heroic`, `gamescope` |
| übersprungene Verzeichnisse | `shadercache`, `downloading` |
| Dateien | ausführbare Dateien jeder Größe, und andere Dateien von 25M oder weniger, neuer als `scan-skip.stamp` |
| Stempel | rückt nur nach einem sauberen Lauf vor |
| abgedeckt | `/var/jeux` |
| nicht abgedeckt | `$HOME/.cache`, `$HOME/snap` |

Ein neuer Fund ruft `clamav-response.sh` auf.

Die Datei wird nach `/var/lib/clamav/quarantine` verschoben. Ein Halter erhält TERM. pid 1, uid 0, ein leerer Name und die Namen systemd, sshd, unbound, fail2ban und gamescope bleiben. Neue ausgehende Flüsse werden für 120 Sekunden isoliert.

Ein bekanntes Paar aus Signatur und Pfad ruft diese Antwort nicht auf.

Ein durch ein Signal gestoppter `clamscan` sendet Post.

Die Post nennt das Signal und jede ungelesene Datei.

Die übrigen Dateien des Laufs werden geprüft.

Zwei Abstürze nacheinander stoppen den ClamAV-Lauf.

Die Post sagt dann, dass die restlichen Dateien nicht gelesen wurden.

Der Stempel bleibt stehen.

## debsums

| Dienst, der überwacht      | Zonen                            | Was als Alarm geht                                                | Befehl der Post                                                           |
| -------------------------- | -------------------------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------------- |
| debsums.sh in boot-scan.sh | Paketdateien, über `debsums -s`. | Jedes verbleibende Paket wird neu installiert. Die Post nennt die Korrektur. | Kein Befehlsblock. |

Die Zeile mirrors.dat wird nur entfernt, wenn der aktuelle Hash zum Stempel passt. Es gibt keine pauschale Ignorierdatei für diesen Pfad.

Eine geänderte Zeile unter `/usr/lib/*/perl-base/unicore/` aus dem Paket `perl-base` wird vor dieser Neuinstallation entfernt.

## auditd

| Dienst, der überwacht | Zonen                                          | Was als Alarm geht                                           | Befehl der Post |
| --------------------- | ---------------------------------------------- | ------------------------------------------------------------ | --------------- |
| auditd                | /etc/audit/rules.d/00-high-fortress-user.rules | Keine eigene Post. behavior.sh im Startlauf sendet die Post eines exec-tmp-Treffers. | Keine.          |

Eine Überwachung mit dem Schlüssel `account` wird für `.ssh/authorized_keys`, `.bashrc`, `.profile`, `.bash_profile`, `.config/autostart` und `.config/systemd/user` hinzugefügt, wenn dieser Pfad schon existiert.

Ein fehlender Pfad wird übersprungen, damit `augenrules` die Regeln weiter lädt.

`tail.rules` zeichnet ptrace-attach, Laden und Entfernen von Modulen und `execve` unter `/tmp`, `/var/tmp` und `/dev/shm` auf.

## Fail2Ban

| Dienst, der überwacht | Zonen                    | Was als Alarm geht | Befehl der Post |
| --------------------- | ------------------------ | ------------------ | --------------- |
| fail2ban              | /etc/fail2ban/jail.local | Keine eigene Post. | Keine.          |

## CrowdSec

| Dienst, der überwacht | Zonen          | Was als Alarm geht | Befehl der Post |
| --------------------- | -------------- | ------------------ | --------------- |
| crowdsec              | /etc/crowdsec/ | Keine eigene Post. | Keine.          |

Die Sperrdauer ist `HFU_CROWDSEC_BAN_DURATION`, Vorgabe `48h`.

Ein Name aus `config/crowdsec/optional.list` wird nur installiert, wenn der Hub ihn annimmt.

## UFW

| Dienst, der überwacht | Zonen                                                                       | Was als Alarm geht | Befehl der Post |
| --------------------- | --------------------------------------------------------------------------- | ------------------ | --------------- |
| ufw                   | Eingehend verweigert, ausgehend erlaubt, Routing erlaubt, Loopback erlaubt. SSH ist auf direkt verbundene Präfixe begrenzt. | Keine eigene Post. | Keine.          |

## Integrität

| Dienst, der überwacht | Zonen | Was als Alarm geht | Befehl der Post |
| --- | --- | --- | --- |
| integrity.sh in boot-scan.sh | `config/integrity/paths.list` | Eine geänderte Prüfsumme. Der erste Lauf schreibt den Stempel und bleibt still. | Kein Befehlsblock. |

Der Lauf folgt auf aide.sh.

Der Stempel ist `/opt/high-fortress-user/cron/integrity.sha256`.

## Verhalten

| Dienst, der überwacht | Zonen | Was als Alarm geht | Befehl der Post |
| --- | --- | --- | --- |
| behavior.sh in boot-scan.sh | `execve` unter `/tmp`, `/var/tmp` und `/dev/shm`. | Ein Treffer seit dem vorherigen Stempel. Der erste Lauf schreibt den Stempel und bleibt still. | Kein Befehlsblock. |

Der Lauf folgt auf rkhunter.sh.

auditd bleibt im Dienst.

Der Stempel ist `/opt/high-fortress-user/cron/behavior.stamp`.

## Ausgehendes Journal

| Dienst, der überwacht | Zonen | Was als Alarm geht | Befehl der Post |
| --- | --- | --- | --- |
| nftables-Tabelle `inet hfu_egress`, dann egress-watch.sh in boot-scan.sh | Neue ausgehende Flüsse außerhalb der Ports 53, 80 und 443. | Eine Kernelzeile mit Präfix `hfu-egress` seit dem vorherigen Stempel. Der erste Lauf schreibt den Stempel und bleibt still. | Kein Befehlsblock. |

Die Tabelle wird mit Politik accept installiert.

Der Lauf folgt auf debsums.sh.

Der Stempel ist `/opt/high-fortress-user/cron/egress.stamp`.

Diese Prüfung isoliert das Netz nicht.

Auf die Kernelzeile folgen der Prozess, die pid und die uid.

Der Audit-Schlüssel ist `hfu-egress`.

Die Tabellenpolitik bleibt accept.

Ausgehend bleibt allow.

## Lynis

| Dienst, der überwacht              | Zonen                     | Was als Alarm geht                                             | Befehl der Post |
| ---------------------------------- | ------------------------- | -------------------------------------------------------------- | --------------- |
| verify/workstation.sh and hf lynis | /var/log/lynis-report.dat | Ein Wert unter 80 ist eine Warnung im Prüfbericht, keine Post. | Keine.          |

`verify/workstation.sh` meldet Secure Boot mit `mokutil`.

Es meldet eine LUKS-Root, wenn `lsblk` für die Root-Quelle `crypt` zeigt.

Fehlt eines von beiden, ist das eine Warnung.

Der Installer lässt beides unverändert.

## Neustart-Hinweis

| Dienst, der überwacht | Zonen | Was als Alarm geht | Befehl der Post |
| --- | --- | --- | --- |
| reboot-notice.sh in hfu-reboot-notice.timer | `/var/run/reboot-required`, `/var/run/reboot-required.pkgs`, und `fwupdmgr get-updates`, wenn dieser Befehl mit 0 endet | Eine neue Menge. Dieselbe Prüfsumme in `reboot-notice.seen` sendet keine Post mehr. | Kein Befehlsblock. |

Der Timer ist `OnUnitActiveSec=6h`, mit `Persistent=false`.

Die Startkette führt diesen Hinweis nach der verzögerten Prüfung aus.

`Nice` ist 19, `IOSchedulingClass` ist `idle`, und `CPUQuota` ist 50 % der ganzen Maschine.

Ein laufendes `lutris`, `heroic` oder `gamescope` überspringt die Post.

Dieser Lauf lässt `reboot-notice.seen` unverändert.

Das Skript startet die Maschine nicht neu.

Die Zusammenfassungszeile ist `Un redémarrage est utile. La machine n'a pas été redémarrée.`
