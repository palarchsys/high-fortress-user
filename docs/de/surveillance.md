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

Von der Zugriffsprüfung ausgeschlossen: jeder akzeptierte Pfad in `/opt/high-fortress-user/cron/scan-skip.paths`, der Benutzer `clamav`, root (`OnAccessExcludeRootUID yes`) und Dateien über 25M. Die bei der Installation gelieferte Datei listet `$HOME/.steam`, `$HOME/.local/share/Steam`, `$HOME/.cache`, `$HOME/snap` und `/var/jeux`. Brave, Thunderbird und Discord stehen nicht darin. Eine relative, leere oder genau `/`, `/home`, `/opt`, `/tmp`, `/etc`, `/usr`, `/var`, `/boot`, `/root`, `/home/<user>`, Downloads oder Desktop gleiche Zeile wird ignoriert und an `/opt/high-fortress-user/cron/security_logs/scan-skip.log` angehängt. `/var/jeux` ist ein leeres Verzeichnis, Modus 750, Eigentümer ist der Benutzer des Arbeitsplatzes. Es ist kein separates Konto. `.clamav-quarantine-lock.*` ist eine Verschiebesperre, keine Schadsoftware, daher endet `clamav-event.sh` mit 0 vor `log_alert`.

Die Liste ändert `scan-skip.sh`. Dieselbe Neuschreibung läuft am Anfang von `boot-scan.sh`. Eine schon vorhandene `scan-skip.paths` bleibt stehen, wenn das Installationsprogramm erneut läuft.

```bash
sudo bash /opt/high-fortress-user/bin/scan-skip.sh list
sudo bash /opt/high-fortress-user/bin/scan-skip.sh add /var/jeux/steam
sudo bash /opt/high-fortress-user/bin/scan-skip.sh del /var/jeux/steam
```

`list` gibt einen akzeptierten Pfad je Zeile aus. `add` gibt `Chemin ajouté : <path>` aus. Ein schon vorhandener Pfad gibt `Ce chemin est déjà exclu : <path>` aus. `del` gibt `Chemin retiré : <path>` aus. Ein abgelehnter Pfad gibt `Chemin refusé : <path>` aus. Der Befehl schreibt die `OnAccessExcludePath`-Zeilen zwischen `# BEGIN High-Fortress User scan-skip` und `# END High-Fortress User scan-skip` in `/etc/clamav/clamd.conf` neu. `clamav-daemon` wird nur neu geladen, wenn dieser Block sich ändert. Ein verborgener Pfad erhält eine `ALLOWHIDDENDIR`-Zeile in `/etc/rkhunter.conf.local`, wenn sie fehlt. Vorhandene rkhunter-Zeilen bleiben.

## ClamAV-Startprüfung

| Dienst, der überwacht     | Zonen             | Was als Alarm geht                              | Befehl der Post    |
| ------------------------- | ----------------- | ----------------------------------------------- | ------------------ |
| clamav.sh in boot-scan.sh | /home, /opt, /tmp | Infektionen. Eine saubere Prüfung bleibt still. | Kein Befehlsblock. |

Die Prüfung schneidet die Zugriffspfade und die akzeptierten Pfade aus `scan-skip.paths` ab. Sie schneidet auch `proc`, `sys`, `dev`, `var/lib/docker`, `var/lib/libvirt`, `libvirt` und `snap-private-tmp` ab. Sie liest die Dateien mit `clamscan` in der Start-Unit. Sie ruft `clamdscan` nicht auf. Brave, Thunderbird und Discord bleiben in diesem Lauf.

## Verzögerte ClamAV-Prüfung

| Dienst, der prüft                   | Zonen                                                                                                      | Was alarmiert wird                                                                                                              | Postbefehl               |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| idle-scan.sh in hfu-idle-scan.timer | Akzeptierte Pfade in `scan-skip.paths`, außer einem Verzeichnis, dessen letzte Komponente `.cache` oder `snap` ist. | Ein neuer Fund. Eine Signatur und ein Pfad, die schon in `/opt/high-fortress-user/cron/scan-skip.seen` stehen, senden keine Post mehr. | Kein Befehlsblock.       |

`hfu-idle-scan.timer` nutzt `OnBootSec=15min`, `OnUnitActiveSec=1h` und `Persistent=true`. `Nice` ist `WATCHDOG_LIMIT_NICE` (19), `IOSchedulingClass=idle`, und `CPUQuota` ist `WATCHDOG_CPU_LIMIT` (20 %). Der Lauf endet mit 0 ohne Prüfung, solange `steam`, `steamwebhelper`, `lutris`, `heroic`, `wineserver` oder `gamescope` läuft. Er überspringt Verzeichnisse namens `shadercache` und `downloading`. Er prüft ausführbare Dateien in jeder Größe und andere Dateien von 25M oder weniger, die neuer sind als `/opt/high-fortress-user/cron/scan-skip.stamp`. Der Stempel rückt nur nach einem sauberen Lauf vor. `/var/jeux`, `$HOME/.steam` und `$HOME/.local/share/Steam` sind abgedeckt. `$HOME/.cache` und `$HOME/snap` nicht.

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
