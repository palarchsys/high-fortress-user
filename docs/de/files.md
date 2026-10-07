[Vollständiges README](README.md)

# Dateien

Jede Zeile ist eine Datei, die das Installationsprogramm schreibt, mit dem Modus, den das Skript setzt. Dateien innerhalb der Ubuntu-Pakete sind nicht einzeln aufgeführt: das Depot benennt sie nicht.

| Pfad                                                    | Rolle                                                                                                             | Rechte                       |
| ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ---------------------------- |
| /opt/high-fortress-user                                 | Laufzeitwurzel.                                                                                                   | 755                          |
| /opt/high-fortress-user/secrets                         | Vom Installationsprogramm reserviertes Verzeichnis. `secrets.conf` liegt hier nicht.                              | 700                          |
| /opt/high-fortress-user/src/config/global.conf                 | Vorbereitete Konfiguration, wenn der Curl-Installer benutzt wurde. Dieselbe Datei liegt in einem Klon in `config/`. | 644                          |
| /opt/high-fortress-user/src/config/secrets.conf                | Von configure.sh geschriebene Geheimnisse. Bleibt auf der Maschine.                                               | 600                          |
| /opt/high-fortress-user/src/hf                          | Starter.                                                                                                          | 755                          |
| /opt/high-fortress-user/bin/aide-refresh-db.sh          | Baut die AIDE-Basis neu.                                                                                          | 755                          |
| /opt/high-fortress-user/bin/chkrootkit-ignore-log.sh    | Speichert erkannte chkrootkit-Zeilen.                                                                             | 755                          |
| /opt/high-fortress-user/bin/debsums-ignore-log.sh       | Speichert erkannte debsums-Zeilen.                                                                                | 755                          |
| /opt/high-fortress-user/cron/bin/*.sh                   | Prüfskripte und mail.sh. Eigentümer root.                                                                         | 750                          |
| /opt/high-fortress-user/cron/bin/mail.html              | Mail-Vorlage.                                                                                                     | 644                          |
| /opt/high-fortress-user/cron/bin/chkrootkit.ignore      | Mitgelieferte chkrootkit-Muster.                                                                                  | 664                          |
| /opt/high-fortress-user/cron/mail.conf                  | HF_MAIL_ALERTS, WATCHDOG_MAIL, PROJECT_NAME, MAIL_TEMPLATE.                                                       | 600                          |
| /opt/high-fortress-user/cron/rkhunter-mirrors.sha256    | Stempel von mirrors.dat nach einem erfolgreichen Update.                                                          | 600                          |
| /etc/cron.d/high-fortress-user                          | Nur SHELL und PATH.                                                                                               | 600                          |
| /etc/systemd/system/hfu-boot-scan.service               | Unit der Startprüfung.                                                                                            | 644                          |
| /etc/systemd/system/hfu-boot-scan.timer                 | Startet die Prüfung 2 Minuten nach dem Start.                                                                     | 644                          |
| /etc/ssh/sshd_config.d/00-high-fortress-user.conf       | SSH-Politik dieses Arbeitsplatzes.                                                                                | 644                          |
| /etc/ssh/sshd_banner                                    | Anmeldebanner.                                                                                                    | 644                          |
| /etc/aide/aide.conf                                     | AIDE-Politik mit ersetztem CONFIG_BASE_DIR.                                                                       | written by redirection       |
| /var/lib/aide/aide.db                                   | AIDE-Basis.                                                                                                       | created by aide --init       |
| /etc/clamav/clamd.conf                                  | Zugriffspfade, ergänzt von service/clamav/configure.sh.                                                           | package file, lines appended |
| /var/lib/clamav/quarantine                              | Quarantäneverzeichnis.                                                                                            | 750                          |
| /etc/sudoers.d/high-fortress-user-clamav                | Erlaubt den sudo-Aufruf von VirusEvent.                                                                           | 440                          |
| /etc/systemd/system/clamav-clamonacc.service.d/hfu.conf | Richtet clamonacc auf das Quarantäneverzeichnis. Der Unit-Name ist der des Pakets.                                | written by redirection       |
| /etc/unbound/unbound.conf.d/high-fortress-user.conf     | Lokaler Resolver.                                                                                                 | 644                          |
| /etc/systemd/system/hfu-unbound-root-hints.service      | Aktualisiert die Root-Hints.                                                                                      | 644                          |
| /etc/systemd/system/hfu-unbound-root-hints.path         | Path-Unit für Root-Hints.                                                                                         | 644                          |
| /etc/apt/sources.list.d/lynis.list                      | CISOfy-Lynis-Herkunft.                                                                                            | 644                          |
| /etc/apt/keyrings/cisofy-software.gpg                   | Lynis-Schlüssel.                                                                                                  | 644                          |
| /etc/apt/sources.list.d/mozilla.sources                 | Thunderbird-Herkunft.                                                                                             | 644                          |
| /etc/apt/sources.list.d/brave-browser-release.sources   | Brave-Herkunft.                                                                                                   | 644                          |
| /etc/apt/apt.conf.d/51high-fortress-user                | Unbeaufsichtigte Upgrades, Neustart aus.                                                                          | written by redirection       |
| /etc/sysctl.d/90-high-fortress-user.conf                | Arbeitsplatz-Sysctl.                                                                                              | 644                          |
| /etc/sysctl.d/99-zzz-high-fortress-user.conf            | Kopie der Sysctl-Datei, zuletzt angewendet.                                                                       | 644                          |
| /etc/lynis/custom.prf                                   | Lynis-Profil dieses Arbeitsplatzes.                                                                               | 644                          |
| /etc/security/pwquality.conf                            | Kennwortqualität.                                                                                                 | written by redirection       |
| /etc/security/faillock.conf                             | Kontosperre.                                                                                                      | written by redirection       |
| /etc/audit/rules.d/00-high-fortress-user.rules          | Audit-Überwachungen.                                                                                              | 640                          |
