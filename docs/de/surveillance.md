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

Ausgeschlossen: `$HOME/.steam`, `$HOME/.local/share/Steam`, der Benutzer `clamav`, root (`OnAccessExcludeRootUID yes`) und Dateien über 25M. `.clamav-quarantine-lock.*` ist eine Verschiebesperre, keine Schadsoftware, daher endet `clamav-event.sh` mit 0 vor `log_alert`.

## ClamAV-Startprüfung

| Dienst, der überwacht     | Zonen             | Was als Alarm geht                              | Befehl der Post    |
| ------------------------- | ----------------- | ----------------------------------------------- | ------------------ |
| clamav.sh in boot-scan.sh | /home, /opt, /tmp | Infektionen. Eine saubere Prüfung bleibt still. | Kein Befehlsblock. |

Die Prüfung schneidet die Zugriffspfade und die Namen `BraveSoftware`, `.config/discord`, `.thunderbird`, `thunderbird`, `libvirt` und `snap-private-tmp` ab, damit diese Bäume nicht zweimal geprüft werden.

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
