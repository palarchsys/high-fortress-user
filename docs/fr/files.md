[README complet](README.md)

# Fichiers

Chaque ligne est un fichier que l'installeur écrit, avec le mode que le script pose. Les fichiers internes des paquets Ubuntu ne sont pas listés un par un : le dépôt ne les nomme pas.

| Chemin                                                  | Rôle                                                                                                              | Droits                       |
| ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ---------------------------- |
| /opt/high-fortress-user                                 | Racine d'exécution.                                                                                               | 755                          |
| /opt/high-fortress-user/secrets                         | Répertoire réservé par l'installeur. `secrets.conf` n'y est pas rangé.                                            | 700                          |
| /opt/high-fortress-user/src/config/global.conf                 | Configuration préparée lorsque l'installeur curl a été utilisé. Le même fichier est dans `config/` dans un clone. | 644                          |
| /opt/high-fortress-user/src/config/secrets.conf                | Secrets écrits par configure.sh. Reste sur la machine.                                                            | 600                          |
| /opt/high-fortress-user/src/hf                          | Lanceur.                                                                                                          | 755                          |
| /opt/high-fortress-user/bin/aide-refresh-db.sh          | Reconstruit la base AIDE.                                                                                         | 755                          |
| /opt/high-fortress-user/bin/chkrootkit-ignore-log.sh    | Enregistre les lignes chkrootkit reconnues.                                                                       | 755                          |
| /opt/high-fortress-user/bin/debsums-ignore-log.sh       | Enregistre les lignes debsums reconnues.                                                                          | 755                          |
| /opt/high-fortress-user/cron/bin/*.sh                   | Scripts de contrôle et mail.sh. Propriétaire root.                                                                | 750                          |
| /opt/high-fortress-user/cron/bin/mail.html              | Modèle de courrier.                                                                                               | 644                          |
| /opt/high-fortress-user/cron/bin/chkrootkit.ignore      | Motifs chkrootkit livrés.                                                                                         | 664                          |
| /opt/high-fortress-user/cron/mail.conf                  | HF_MAIL_ALERTS, WATCHDOG_MAIL, PROJECT_NAME, MAIL_TEMPLATE.                                                       | 600                          |
| /opt/high-fortress-user/cron/rkhunter-mirrors.sha256    | Empreinte de mirrors.dat après une mise à jour réussie.                                                           | 600                          |
| /etc/cron.d/high-fortress-user                          | SHELL et PATH seulement.                                                                                          | 600                          |
| /etc/systemd/system/hfu-boot-scan.service               | Unité de la passe de démarrage.                                                                                   | 644                          |
| /etc/systemd/system/hfu-boot-scan.timer                 | Lance la passe 2 minutes après le démarrage.                                                                      | 644                          |
| /etc/ssh/sshd_config.d/00-high-fortress-user.conf       | Politique SSH de ce poste.                                                                                        | 644                          |
| /etc/ssh/sshd_banner                                    | Bannière de connexion.                                                                                            | 644                          |
| /etc/aide/aide.conf                                     | Politique AIDE avec CONFIG_BASE_DIR substitué.                                                                    | written by redirection       |
| /var/lib/aide/aide.db                                   | Base AIDE.                                                                                                        | created by aide --init       |
| /etc/clamav/clamd.conf                                  | Chemins d'accès ajoutés par service/clamav/configure.sh.                                                          | package file, lines appended |
| /var/lib/clamav/quarantine                              | Répertoire de quarantaine.                                                                                        | 750                          |
| /etc/sudoers.d/high-fortress-user-clamav                | Autorise l'appel sudo de VirusEvent.                                                                              | 440                          |
| /etc/systemd/system/clamav-clamonacc.service.d/hfu.conf | Dirige clamonacc vers le répertoire de quarantaine. Le nom d'unité est celui du paquet.                           | written by redirection       |
| /etc/unbound/unbound.conf.d/high-fortress-user.conf     | Résolveur local.                                                                                                  | 644                          |
| /etc/systemd/system/hfu-unbound-root-hints.service      | Rafraîchit les indications racine.                                                                                | 644                          |
| /etc/systemd/system/hfu-unbound-root-hints.path         | Unité path des indications racine.                                                                                | 644                          |
| /etc/apt/sources.list.d/lynis.list                      | Origine Lynis CISOfy.                                                                                             | 644                          |
| /etc/apt/keyrings/cisofy-software.gpg                   | Clé Lynis.                                                                                                        | 644                          |
| /etc/apt/sources.list.d/mozilla.sources                 | Origine Thunderbird.                                                                                              | 644                          |
| /etc/apt/sources.list.d/brave-browser-release.sources   | Origine Brave.                                                                                                    | 644                          |
| /etc/apt/apt.conf.d/51high-fortress-user                | Mises à jour automatiques, redémarrage coupé.                                                                     | written by redirection       |
| /etc/sysctl.d/90-high-fortress-user.conf                | Sysctl du poste.                                                                                                  | 644                          |
| /etc/sysctl.d/99-zzz-high-fortress-user.conf            | Copie du fichier sysctl appliquée en dernier.                                                                     | 644                          |
| /etc/lynis/custom.prf                                   | Profil Lynis de ce poste.                                                                                         | 644                          |
| /etc/security/pwquality.conf                            | Qualité des mots de passe.                                                                                        | written by redirection       |
| /etc/security/faillock.conf                             | Verrouillage de compte.                                                                                           | written by redirection       |
| /etc/audit/rules.d/00-high-fortress-user.rules          | Surveillances d'audit.                                                                                            | 640                          |
