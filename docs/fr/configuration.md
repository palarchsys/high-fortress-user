[README complet](README.md)

# Configuration

Les noms et les défauts ci-dessous sont le `user/config/global.conf` livré et `hfu_set_config_default`. Les crochets d'une question sont la valeur qu'Entrée conserve.

## Variables générales

| Nom                        | Défaut                                                           | Effet                                                                                              |
| -------------------------- | ---------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| HF_CONFIG_PREPARED                | 1                                                                | Doit valoir 1, sinon le contrôle refuse les fichiers.                                              |
| HF_PROJECT_NAME               | High-Fortress User                                               | Affiché dans le courrier. Non demandé.                                                             |
| HFU_PROJECT_SLUG               | high-fortress-user                                               | Fixé par le contrôle. Nomme `/etc/cron.d/high-fortress-user`.                                                 |
| HF_PROJECT_VERSION            | 0.2                                                              | Enregistrée. Non demandée.                                                                         |
| HF_CONFIG_BASE_DIRECTORY            | /opt/high-fortress-user                                          | Racine d'exécution.                                                     |
| HF_SECRET_DIRECTORY                | /opt/high-fortress-user/secrets                                  | Créé en mode 700. `secrets.conf` n'y est pas écrit.                                                |
| HF_DEBUG_INSTALL_LOG         | 0                                                                | Présent dans le fichier. Les journaux d'installation vont toujours dans `<source>/logs/`.         |
| HF_MODE_TEST                  | 1                                                                | Demandé. `1` saute la question de retrait à la fin. `0` la pose.                                   |
| HF_LYNIS_MIN_SCORE            | 80                                                               | Indice de durcissement minimum accepté. Non demandé.                                               |
| HFU_OS_ID                  | ubuntu                                                           | Fixé par le contrôle.                                                                              |
| HFU_OS_VERSION             | 26.04                                                            | Fixé par le contrôle.                                                                              |
| HF_BANNER_MESSAGE             | text in global.conf                                              | Écrit dans `/etc/ssh/sshd_banner`. Non demandé.                                                    |
| HF_SSH_BANNER_PATH            | /etc/ssh/sshd_banner                                             | Fichier de bannière. Non demandé.                                                                  |
| HF_SSH_SERVICE_NAME           | ssh                                                              | Nom du service. Non demandé.                                                                       |
| HF_SSH_MAX_AUTH_TRIES         | 4                                                                | sshd `MaxAuthTries`. Non demandé.                                                                  |
| HF_SSH_CLIENT_ALIVE_INTERVAL  | 300                                                              | Intervalle sshd en secondes. Non demandé.                                                          |
| HF_SSH_CLIENT_ALIVE_COUNT_MAX | 2                                                                | Nombre de sondes sshd. Non demandé.                                                                |
| HFU_SSH_LOGIN_GRACE_TIME       | 30                                                               | Délai sshd en secondes. Non demandé.                                                               |
| HFU_PAM_PASSWORD_MIN_LENGTH           | 12                                                               | Longueur minimale dans `/etc/security/pwquality.conf`. Non demandée.                               |
| HFU_FAILLOCK_DENY              | 8                                                                | Échecs avant verrouillage. Non demandé.                                                            |
| HFU_FAILLOCK_UNLOCK            | 600                                                              | Secondes de verrouillage. Non demandé.                                                             |
| HFU_FAILLOCK_FAIL_INTERVAL     | 900                                                              | Fenêtre de comptage des échecs. Non demandée.                                                      |
| HF_WATCHDOG_CPU_LIMIT         | 50                                                               | Pourcentage de la machine pour une passe. L'unité écrit `CPUQuota` comme ce nombre fois le nombre de CPU. Non demandé. |
| HF_WATCHDOG_LIMIT_NICE        | 19                                                               | Valeur nice de la passe de démarrage. Non demandée.                                                |
| HF_WATCHDOG_LIMIT_IO_NICE      | 3                                                                | Classe ionice enregistrée dans le fichier. Le timer utilise `IOSchedulingClass=idle`. Non demandé. |
| HF_MAIL_ALERTS             | 1 in the shipped file, 0 in the builtin default until you answer | Posé par la réponse sur les alertes.                                                               |
| HF_MAIL_TEMPLATE              | mail.html                                                        | Modèle HTML copié dans `cron/bin`. Non demandé.                                                    |

## secrets.conf

Le fichier est écrit dans `config/`, à côté de `global.conf`, mode `600`, propriétaire root. Il n'est pas écrit dans `HF_SECRET_DIRECTORY`. Les valeurs ne sont pas listées ici.

| Nom                  | Où           | Règle                                                            |
| -------------------- | ------------ | ---------------------------------------------------------------- |
| HF_UBUNTU_PRO_TOKEN     | secrets.conf | Demandé. Obligatoire. Lettres et chiffres, 6 à 100.              |
| HF_POSTFIX_SMTP_LOGIN   | secrets.conf | Demandé seulement si les alertes sont activées.                  |
| HF_POSTFIX_MAIL_ADDRESS | secrets.conf | Adresse From. Copiée aussi dans `HF_WATCHDOG_MAIL`.                 |
| HF_POSTFIX_MAIL_PASSWORD    | secrets.conf | Mot de passe d'application, 8 à 128 caractères, espaces retirés. |
| HF_POSTFIX_MAIL_SMTP    | secrets.conf | `hôte:port` sans crochets.                                       |
| HF_WATCHDOG_MAIL        | secrets.conf | Même valeur que `HF_POSTFIX_MAIL_ADDRESS`.                          |
| HF_SECRET_PREPARED  | secrets.conf | Posé à 1 par l'écriture. Non demandé.                            |

## Variables par service

| Nom                           | Défaut                                    | Effet                                                                      |
| ----------------------------- | ----------------------------------------- | -------------------------------------------------------------------------- |
| OnAccessIncludePath           | Dossiers XDG, /tmp, /var/tmp, /opt        | Téléchargements, Bureau, Documents, Musique, Images, Vidéos, /tmp, /var/tmp et /opt. |
| HFU_ONACCESS_MOUNTS           | 1                                         | 0 laisse /media et /mnt dehors.                                  |
| signal de processus           | toujours                                  | Signale un processus non critique qui tient le fichier détecté. Le pid 1, root, systemd, sshd, unbound, fail2ban et gamescope restent en cours. |
| OnAccessExcludePath           | config/clamav/scan-skip.paths             | Chemins acceptés sous le home de l'utilisateur, ou sous `/var/jeux`. |
| OnAccessExcludeUname          | clamav                                    | L'utilisateur du scanner est exclu.                                        |
| OnAccessExcludeRootUID        | yes                                       | Root est exclu de l'analyse à l'accès sur ce poste.                        |
| OnAccessMaxFileSize           | 25M                                       | Les fichiers plus gros ne sont pas analysés à l'accès.                     |
| OnAccessPrevention            | yes                                       | Une détection est déplacée en quarantaine.                                 |
| quarantine                    | /var/lib/clamav/quarantine                | Mode 750, propriétaire clamav.                                             |
| hfu-boot-chain.timer          | OnBootSec=0, Persistent=false             | Lance la chaîne lorsque `multi-user.target` est atteint. La session n'attend pas. |
| hfu-idle-scan.timer           | OnUnitActiveSec=1h, Persistent=false      | Même Nice, mêmes entrées-sorties idle et même quota CPU que la passe de démarrage. Pas de délai fixe après le démarrage. |
| hfu-reboot-notice.timer       | OnUnitActiveSec=6h, Persistent=false      | Même quota. Le script ne redémarre pas la machine. |
| hfu-periodic-scan.timer       | OnBootSec=2h, OnUnitActiveSec=2h          | Lance seulement clamav.sh. Même Nice, mêmes E/S idle et même quota CPU. Persistent=false. |
| integrity.sh                  | boot-scan.sh, après aide.sh           | Empreinte de config/integrity/paths.list. La première passe écrit cron/integrity.sha256 et reste silencieuse. |
| behavior.sh                   | boot-scan.sh, après rkhunter.sh       | Lit les événements exec-tmp depuis cron/behavior.stamp. La première passe écrit le cachet et reste silencieuse. auditd reste en service. |
| inet hfu_egress               | installée                             | Journalise les flux sortants nouveaux hors des ports 53, 80 et 443. Politique accept. Le sortant reste allow. |
| egress-watch.sh               | boot-scan.sh, après debsums.sh        | Lit les lignes noyau préfixées hfu-egress depuis cron/egress.stamp. La première passe écrit le cachet et reste silencieuse. |
| isolation réseau              | toujours                                  | Après une détection, refuse les nouveaux flux sortants pendant HFU_NET_ISOLATE_SEC. La boucle locale, le DNS et les flux établis restent. La politique sortante reste allow. |
| HFU_NET_ISOLATE_SEC           | 120                                       | Secondes avant le retrait de cette isolation. Minimum 30, maximum 300. |
| HFU_CROWDSEC_BAN_DURATION     | 48h                                       | Écrit dans les profils CrowdSec. |
| scan-skip.sh                  | /opt/high-fortress-user/bin/scan-skip.sh  | Relance `clamav-daemon` et `clamonacc` lorsque le bloc d'exclusion change. |
| database_in                   | /var/lib/aide/aide.db                     | `__HF_BASE__` dans `config/aide/aide.conf` devient `HF_CONFIG_BASE_DIRECTORY`.     |

## Docker

Ce poste n'a pas d'arbre `docker/`. Aucune image, étiquette, port ou volume n'est posé par cet installeur.

## Non demandé, et généré

Les valeurs demandées sont le jeton Ubuntu Pro, le choix des alertes, les champs SMTP lorsque les alertes sont activées, et `HF_MODE_TEST`. Tout le reste des tableaux n'est pas demandé. Rien n'est généré avec `openssl`. `HF_MAIL_ALERTS` vaut `1` ou `0` selon la réponse. Les champs de courrier vides sont écrits lorsque les alertes sont coupées.
