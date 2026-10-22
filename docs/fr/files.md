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
| /opt/high-fortress-user/bin/rkhunter-refresh-db.sh      | Recalcule la base de propriétés rkhunter.                                                                         | 755                          |
| /opt/high-fortress-user/bin/chkrootkit-ignore-log.sh    | Enregistre les lignes chkrootkit reconnues.                                                                       | 755                          |
| /opt/high-fortress-user/bin/debsums-ignore-log.sh       | Enregistre les lignes debsums reconnues.                                                                          | 755                          |
| /opt/high-fortress-user/cron/bin/*.sh                   | Scripts de contrôle, mail.sh et watchdog.sh partagé. Propriétaire root.                                          | 750                          |
| /opt/high-fortress-user/cron/bin/mail.html              | Modèle de courrier.                                                                                               | 644                          |
| /opt/high-fortress-user/src/config/chkrootkit/patterns.ignore | Motifs chkrootkit livrés.                                                                                         | 664                          |
| /opt/high-fortress-user/cron/mail.conf                  | HF_MAIL_ALERTS, HF_WATCHDOG_MAIL, HF_PROJECT_NAME, HF_MAIL_TEMPLATE.                                                       | 600                          |
| /opt/high-fortress-user/cron/rkhunter-mirrors.sha256    | Empreinte de mirrors.dat après une mise à jour réussie.                                                           | 600                          |
| /etc/cron.d/high-fortress-user                          | SHELL et PATH seulement.                                                                                          | 600                          |
| /etc/systemd/system/hfu-boot-scan.service               | Unité de la passe de démarrage.                                                                                   | 644                          |
| /etc/systemd/system/hfu-boot-chain.service              | Lance la passe, puis l'analyse différée, puis l'avis de redémarrage.                                             | 644                          |
| /etc/systemd/system/hfu-boot-chain.timer                | Lance la chaîne lorsque multi-user.target est atteint.                                                           | 644                          |
| /etc/systemd/system/hfu-idle-scan.service               | Analyse différée des chemins exclus.                                                                              | 644                          |
| /etc/systemd/system/hfu-idle-scan.timer                 | Relance cette analyse toutes les heures après la chaîne.                                                         | 644                          |
| /etc/systemd/system/hfu-reboot-notice.service           | Avis lorsqu'un redémarrage est utile. Le script ne redémarre pas la machine.                             | 644                          |
| /etc/systemd/system/hfu-reboot-notice.timer             | Relance cet avis toutes les 6 heures après la chaîne.                                                    | 644                          |
| /etc/systemd/system/hfu-periodic-scan.service           | Passe ClamAV toutes les 2 heures. Mêmes limites CPU et E/S que la passe de démarrage.                    | 644                          |
| /etc/systemd/system/hfu-periodic-scan.timer             | Lance cette passe 2 heures après le démarrage, puis toutes les 2 heures.                                 | 644                          |
| /etc/systemd/system/hfu-hourly-scan.service             | Passe horaire AIDE, rkhunter, chkrootkit et debsums. Mêmes limites CPU et E/S que la passe de démarrage. | 644                          |
| /etc/systemd/system/hfu-hourly-scan.timer               | Lance cette passe 1 heure après le démarrage, puis toutes les heures.                                    | 644                          |
| /opt/high-fortress-user/cron/integrity.sha256           | Cachet d'empreinte écrit par integrity.sh pendant la passe de démarrage.                                | 600                          |
| /opt/high-fortress-user/cron/behavior.stamp             | Cachet de fenêtre d'audit écrit par behavior.sh pendant la passe de démarrage.                  | 600                          |
| /opt/high-fortress-user/cron/egress.stamp               | Cachet de fenêtre du journal sortant écrit par egress-watch.sh pendant la passe de démarrage.   | 600                          |
| /opt/high-fortress-user/cron/bin/clamav-response.sh     | Quarantaine, signal de processus et isolation courte après une détection.                       | 750                          |
| /opt/high-fortress-user/src/service/apparmor/detect-and-apply.sh | Charge un profil hfu seulement si le programme existe.                                            | 755                          |
| /opt/high-fortress-user/bin/scan-skip.sh                | Liste, ajoute ou retire un chemin exclu, puis relance ClamAV lorsque le bloc change.                             | 755                          |
| /opt/high-fortress-user/bin/boot-check.sh               | Vérifie que les services de sécurité du démarrage ont fini cette session.                                        | 755                          |
| /opt/high-fortress-user/src/config/clamav/scan-skip.paths | Chemins exclus. Le modèle est rempli seulement lorsque le fichier est encore absent.                              | 644                          |
| /opt/high-fortress-user/cron/scan-skip.stamp            | Tampon de date de l'analyse différée.                                                                             | 644                          |
| /opt/high-fortress-user/cron/scan-skip.seen             | Couples signature et chemin déjà envoyés par l'analyse différée.                                                  | 600                          |
| /opt/high-fortress-user/cron/reboot-notice.seen         | Empreinte du dernier ensemble de redémarrage déjà envoyé.                                                 | 600                          |
| /var/jeux                                                   | Répertoire vide pour une bibliothèque de jeux. Pas un compte séparé.                                              | 750                          |
| /etc/ssh/sshd_config.d/00-high-fortress-user.conf       | Politique SSH de ce poste.                                                                                        | 644                          |
| /etc/ssh/sshd_banner                                    | Bannière de connexion.                                                                                            | 644                          |
| /etc/aide/aide.conf                                     | Politique AIDE avec HF_CONFIG_BASE_DIRECTORY substitué.                                                                    | written by redirection       |
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
| /etc/apt/apt.conf.d/51high-fortress-user                | Mises à jour automatiques, redémarrage coupé.                                                                     | written by redirection       |
| /etc/sysctl.d/90-high-fortress-user.conf                | Sysctl du poste.                                                                                                  | 644                          |
| /etc/sysctl.d/99-zzz-high-fortress-user.conf            | Copie du fichier sysctl appliquée en dernier.                                                                     | 644                          |
| /etc/lynis/custom.prf                                   | Profil Lynis de ce poste.                                                                                         | 644                          |
| /etc/security/pwquality.conf                            | Qualité des mots de passe.                                                                                        | written by redirection       |
| /etc/security/faillock.conf                             | Verrouillage de compte.                                                                                           | written by redirection       |
| /etc/audit/rules.d/00-high-fortress-user.rules          | Surveillances d'audit.                                                                                            | 640                          |
| /etc/sudoers.d/high-fortress-user-timeout               | sudo redemande le mot de passe après 5 minutes.                                                            | 440                          |
| /etc/usbguard/rules.conf                                | Appareils présents, claviers, souris et concentrateurs.                                                    | 600                          |
| /etc/usbguard/IPCAccessControl.d/<user>                 | Permet au compte du bureau d'accepter un appareil nouveau.                                                 | 600                          |
