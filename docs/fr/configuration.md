[README complet](README.md)

# Configuration

Les noms et les défauts ci-dessous sont le `user/config/global.conf` livré et `hfu_config_set_builtin_defaults`. Les crochets d'une question sont la valeur qu'Entrée conserve.

## Variables générales

| Nom                        | Défaut                                                           | Effet                                                                                              |
| -------------------------- | ---------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| HF_PREPARED                | 1                                                                | Doit valoir 1, sinon le contrôle refuse les fichiers.                                              |
| PROJECT_NAME               | High-Fortress User                                               | Affiché dans le courrier. Non demandé.                                                             |
| PROJECT_SLUG               | high-fortress-user                                               | Fixé par le contrôle. Construit `CONFIG_BASE_DIR`.                                                 |
| PROJECT_VERSION            | 0.2                                                              | Enregistrée. Non demandée.                                                                         |
| CONFIG_BASE_DIR            | /opt/high-fortress-user                                          | Racine d'exécution. Dérivée de `PROJECT_SLUG`.                                                     |
| SECRETS_DIR                | /opt/high-fortress-user/secrets                                  | Créé en mode 700. `secrets.conf` n'y est pas écrit.                                                |
| DEBUG_INSTALL_LOGS         | 0                                                                | Présent dans le fichier. Les journaux d'installation vont toujours dans `<source>/logs/`.         |
| MODE_TEST                  | 1                                                                | Demandé. `1` saute la question de retrait à la fin. `0` la pose.                                   |
| LYNIS_MIN_SCORE            | 80                                                               | Indice de durcissement minimum accepté. Non demandé.                                               |
| HFU_OS_ID                  | ubuntu                                                           | Fixé par le contrôle.                                                                              |
| HFU_OS_VERSION             | 26.04                                                            | Fixé par le contrôle.                                                                              |
| BANNER_MESSAGE             | text in global.conf                                              | Écrit dans `/etc/ssh/sshd_banner`. Non demandé.                                                    |
| SSH_BANNER_PATH            | /etc/ssh/sshd_banner                                             | Fichier de bannière. Non demandé.                                                                  |
| SSH_SERVICE_NAME           | ssh                                                              | Nom du service. Non demandé.                                                                       |
| SSH_MAX_AUTH_TRIES         | 4                                                                | sshd `MaxAuthTries`. Non demandé.                                                                  |
| SSH_CLIENT_ALIVE_INTERVAL  | 300                                                              | Intervalle sshd en secondes. Non demandé.                                                          |
| SSH_CLIENT_ALIVE_COUNT_MAX | 2                                                                | Nombre de sondes sshd. Non demandé.                                                                |
| SSH_LOGIN_GRACE_TIME       | 30                                                               | Délai sshd en secondes. Non demandé.                                                               |
| PWQUALITY_MINLEN           | 12                                                               | Longueur minimale dans `/etc/security/pwquality.conf`. Non demandée.                               |
| FAILLOCK_DENY              | 8                                                                | Échecs avant verrouillage. Non demandé.                                                            |
| FAILLOCK_UNLOCK            | 600                                                              | Secondes de verrouillage. Non demandé.                                                             |
| FAILLOCK_FAIL_INTERVAL     | 900                                                              | Fenêtre de comptage des échecs. Non demandée.                                                      |
| WATCHDOG_CPU_LIMIT         | 20                                                               | Quota CPU en pour cent de la passe de démarrage. Non demandé.                                      |
| WATCHDOG_LIMIT_NICE        | 19                                                               | Valeur nice de la passe de démarrage. Non demandée.                                                |
| WATCHDOG_LIMIT_IONICE      | 3                                                                | Classe ionice enregistrée dans le fichier. Le timer utilise `IOSchedulingClass=idle`. Non demandé. |
| HF_MAIL_ALERTS             | 1 in the shipped file, 0 in the builtin default until you answer | Posé par la réponse sur les alertes.                                                               |
| MAIL_TEMPLATE              | mail.html                                                        | Modèle HTML copié dans `cron/bin`. Non demandé.                                                    |

## secrets.conf

Le fichier est écrit dans `config/`, à côté de `global.conf`, mode `600`, propriétaire root. Il n'est pas écrit dans `SECRETS_DIR`. Les valeurs ne sont pas listées ici.

| Nom                  | Où           | Règle                                                            |
| -------------------- | ------------ | ---------------------------------------------------------------- |
| UBUNTU_PRO_TOKEN     | secrets.conf | Demandé. Obligatoire. Lettres et chiffres, 6 à 100.              |
| POSTFIX_SMTP_LOGIN   | secrets.conf | Demandé seulement si les alertes sont activées.                  |
| POSTFIX_MAIL_ADDRESS | secrets.conf | Adresse From. Copiée aussi dans `WATCHDOG_MAIL`.                 |
| POSTFIX_MAIL_PASS    | secrets.conf | Mot de passe d'application, 8 à 128 caractères, espaces retirés. |
| POSTFIX_MAIL_SMTP    | secrets.conf | `hôte:port` sans crochets.                                       |
| WATCHDOG_MAIL        | secrets.conf | Même valeur que `POSTFIX_MAIL_ADDRESS`.                          |
| HF_SECRETS_PREPARED  | secrets.conf | Posé à 1 par l'écriture. Non demandé.                            |

## Variables par service

| Nom                           | Défaut                                    | Effet                                                                      |
| ----------------------------- | ----------------------------------------- | -------------------------------------------------------------------------- |
| OnAccessIncludePath           | Téléchargements et Bureau                 | `xdg-user-dir`, ou `$HOME/Downloads` et `$HOME/Desktop`.                   |
| OnAccessExcludePath           | $HOME/.steam and $HOME/.local/share/Steam | Les données Steam ne sont pas analysées à l'accès.                         |
| OnAccessExcludeUname          | clamav                                    | L'utilisateur du scanner est exclu.                                        |
| OnAccessExcludeRootUID        | yes                                       | Root est exclu de l'analyse à l'accès sur ce poste.                        |
| OnAccessMaxFileSize           | 25M                                       | Les fichiers plus gros ne sont pas analysés à l'accès.                     |
| OnAccessPrevention            | yes                                       | Une détection est déplacée en quarantaine.                                 |
| quarantine                    | /var/lib/clamav/quarantine                | Mode 750, propriétaire clamav.                                             |
| hfu-boot-scan.timer OnBootSec | 2min                                      | `Persistent=false`. Une machine déjà allumée attend le prochain démarrage. |
| database_in                   | /var/lib/aide/aide.db                     | `__HF_BASE__` dans `service/aide/aide.conf` devient `CONFIG_BASE_DIR`.     |

## Docker

Ce poste n'a pas d'arbre `docker/`. Aucune image, étiquette, port ou volume n'est posé par cet installeur.

## Non demandé, et généré

Les valeurs demandées sont le jeton Ubuntu Pro, le choix des alertes, les champs SMTP lorsque les alertes sont activées, et `MODE_TEST`. Tout le reste des tableaux n'est pas demandé. Rien n'est généré avec `openssl`. `HF_MAIL_ALERTS` vaut `1` ou `0` selon la réponse. Les champs de courrier vides sont écrits lorsque les alertes sont coupées.
