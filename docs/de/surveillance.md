[Vollständiges README](README.md)

# Überwachung

## AIDE

| Dienst, der überwacht   | Zonen                                               | Was als Alarm geht                                                       | Befehl der Post                                            |
| ----------------------- | --------------------------------------------------- | ------------------------------------------------------------------------ | ---------------------------------------------------------- |
| aide.sh in boot-scan.sh | /etc/aide/aide.conf, database /var/lib/aide/aide.db | Änderungen, oder ein Code ungleich null, der kein sauberes Ergebnis ist. | `sudo bash /opt/high-fortress-user/bin/aide-refresh-db.sh` |

Flüchtige Pfade, Journale, Caches und die Cron-Berichtverzeichnisse sind in `service/aide/aide.conf` ausgeschlossen, damit die Basis nicht von diesen Dateien neu geschrieben wird.

## rkhunter

| Dienst, der überwacht       | Zonen                                              | Was als Alarm geht                                                                         | Befehl der Post    |
| --------------------------- | -------------------------------------------------- | ------------------------------------------------------------------------------------------ | ------------------ |
| rkhunter.sh in boot-scan.sh | Prüfumfang des Pakets, plus die Eigenschaftsbasis. | Warnungen, ein fehlgeschlagenes Update, oder `mirrors.dat modifié hors rkhunter --update`. | Kein Befehlsblock. |

`/var/lib/rkhunter/db/mirrors.dat` wird nicht als Datei ignoriert. Der Stempel `/opt/high-fortress-user/cron/rkhunter-mirrors.sha256` wird nur geschrieben, wenn `rkhunter --update` 0 oder 2 zurückgibt. Ein anderer Hash ist ein Alarm. Die Prüfung läuft vor dem nächsten `--update`.

## chkrootkit

| Dienst, der überwacht         | Zonen                   | Was als Alarm geht                                 | Befehl der Post                                                              |
| ----------------------------- | ----------------------- | -------------------------------------------------- | ---------------------------------------------------------------------------- |
| chkrootkit.sh in boot-scan.sh | /usr/sbin/chkrootkit -q | Jede verbleibende Ausgabe nach den Ignorierlisten. | `sudo bash /opt/high-fortress-user/bin/chkrootkit-ignore-log.sh '<journal>'` |

Bekannte Zeilen stehen in `cron/bin/chkrootkit.ignore` und in `cron/chkrootkit.local.ignore`. Die lokale Datei wird nur durch den Befehl aus der Post gefüllt, und nur für Zeilen, die Sie erkennen.

## ClamAV beim Zugriff

| Dienst, der überwacht           | Zonen                  | Was als Alarm geht                              | Befehl der Post                    |
| ------------------------------- | ---------------------- | ----------------------------------------------- | ---------------------------------- |
| clamonacc, then clamav-event.sh | Downloads und Desktop. | Ein echter Fund. Sperrdateien alarmieren nicht. | `sudo ls -la -- <quarantine path>` |

| Ausschluss | Regel |
| --- | --- |
| `scan-skip.paths` | Nur akzeptierte Pfade. |
| Benutzer `clamav` | `OnAccessExcludeUname clamav` |
| root | `OnAccessExcludeRootUID yes` |
| Größe | Dateien über 25M. |

Die gelieferte Datei listet:

- `$HOME/.steam`
- `$HOME/.local/share/Steam`
- `$HOME/.cache`
- `$HOME/snap`
- `/var/jeux`

Brave, Thunderbird und Discord bleiben in der Prüfung.

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

`clamav-event.sh` endet mit 0 vor `log_alert`.

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
| clamav.sh in boot-scan.sh | /home, /opt, /tmp | Infektionen. Eine saubere Prüfung bleibt still. | Kein Befehlsblock. |

Die Prüfung schneidet die Zugriffspfade ab.

Die Prüfung schneidet die akzeptierten Pfade aus `scan-skip.paths` ab.

Die Prüfung schneidet auch `proc`, `sys`, `dev`, `var/lib/docker`, `var/lib/libvirt`, `libvirt` und `snap-private-tmp` ab.

Die Prüfung liest die Dateien mit `clamscan` in der Start-Unit.

Brave, Thunderbird und Discord bleiben in diesem Lauf.

## Verzögerte ClamAV-Prüfung

| Dienst, der prüft                   | Zonen                                                                                                      | Was alarmiert wird                                                                                                              | Postbefehl               |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| idle-scan.sh in hfu-idle-scan.timer | Akzeptierte Pfade, außer `.cache` und `snap`. | Ein neuer Fund. Ein bekanntes Paar in `scan-skip.seen` sendet keine Post mehr. | Kein Befehlsblock. |

| Einstellung | Wert |
| --- | --- |
| Timer | `OnBootSec=15min`, `OnUnitActiveSec=1h`, `Persistent=true` |
| Grenzen | `Nice` 19, `IOSchedulingClass=idle`, `CPUQuota` 20 % |
| Warten | `steam`, `steamwebhelper`, `lutris`, `heroic`, `wineserver`, `gamescope` |
| übersprungene Verzeichnisse | `shadercache`, `downloading` |
| Dateien | ausführbare Dateien jeder Größe, und andere Dateien von 25M oder weniger, neuer als `scan-skip.stamp` |
| Stempel | rückt nur nach einem sauberen Lauf vor |
| abgedeckt | `/var/jeux`, `$HOME/.steam`, `$HOME/.local/share/Steam` |
| nicht abgedeckt | `$HOME/.cache`, `$HOME/snap` |

## debsums

| Dienst, der überwacht      | Zonen                            | Was als Alarm geht                                                | Befehl der Post                                                           |
| -------------------------- | -------------------------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------------- |
| debsums.sh in boot-scan.sh | Paketdateien, über `debsums -s`. | Geänderte Paketdateien, die nicht auf einer Ignorierliste stehen. | `sudo bash /opt/high-fortress-user/bin/debsums-ignore-log.sh '<journal>'` |

Die Zeile mirrors.dat wird nur entfernt, wenn der aktuelle Hash zum Stempel passt. Es gibt keine pauschale Ignorierdatei für diesen Pfad.

## auditd

| Dienst, der überwacht | Zonen                                          | Was als Alarm geht                                           | Befehl der Post |
| --------------------- | ---------------------------------------------- | ------------------------------------------------------------ | --------------- |
| auditd                | /etc/audit/rules.d/00-high-fortress-user.rules | Keine eigene Post. Der Startlauf sendet keinen auditd-Alarm. | Keine.          |

## Fail2Ban

| Dienst, der überwacht | Zonen                    | Was als Alarm geht | Befehl der Post |
| --------------------- | ------------------------ | ------------------ | --------------- |
| fail2ban              | /etc/fail2ban/jail.local | Keine eigene Post. | Keine.          |

## CrowdSec

| Dienst, der überwacht | Zonen          | Was als Alarm geht | Befehl der Post |
| --------------------- | -------------- | ------------------ | --------------- |
| crowdsec              | /etc/crowdsec/ | Keine eigene Post. | Keine.          |

## UFW

| Dienst, der überwacht | Zonen                                                                       | Was als Alarm geht | Befehl der Post |
| --------------------- | --------------------------------------------------------------------------- | ------------------ | --------------- |
| ufw                   | Eingehend verweigert, ausgehend erlaubt, Routing erlaubt, Loopback erlaubt. | Keine eigene Post. | Keine.          |

## Lynis

| Dienst, der überwacht              | Zonen                     | Was als Alarm geht                                             | Befehl der Post |
| ---------------------------------- | ------------------------- | -------------------------------------------------------------- | --------------- |
| verify/workstation.sh and hf lynis | /var/log/lynis-report.dat | Ein Wert unter 80 ist eine Warnung im Prüfbericht, keine Post. | Keine.          |
