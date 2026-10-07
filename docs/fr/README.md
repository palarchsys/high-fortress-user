# High-Fortress User

## Description

High-Fortress User prépare un poste Ubuntu 26.04. Il installe les programmes de bureau, le résolveur DNS local, le pare-feu et les contrôles de sécurité.

Le compte Ubuntu déjà créé sur la machine n'est pas remplacé. L'installeur ne crée pas un second compte.

`secrets.conf` reste sur la machine. Ne le copiez pas dans un message, un ticket ou un dépôt.

## Avant de commencer

### Système

Ubuntu 26.04. Une installation neuve est préférable. Utilisez une console locale ou la session graphique déjà ouverte. La machine a besoin d'Internet.

### Accès

Vous avez besoin de `sudo` pour `./hf configure`, `./hf run` et les contrôles.

### Besoins externes

| Besoin                     | Lien et procédure                                                                                                                                                                                                                             |
| -------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Jeton Ubuntu Pro           | Obligatoire. Ouvrez [https://ubuntu.com/pro/dashboard](https://ubuntu.com/pro/dashboard) et copiez le jeton. `configure.sh` accepte seulement des lettres et des chiffres, longueur 6 à 100, sans espace.                                     |
| Mot de passe d'application | Demandé seulement si vous activez les alertes. Utilisez le mot de passe d'application du fournisseur de courrier. Ne saisissez jamais le mot de passe du compte. Longueur 8 à 128. Les espaces saisis sont retirés.                           |
| Serveur SMTP               | Demandé seulement si les alertes sont activées. Forme `hôte:port`. L'exemple de `configure.sh` est `smtp-mail.outlook.com:587`. Les crochets sont refusés. `swaks` envoie un message d'essai. La ligne de succès est `Essai d'envoi accepté.` |

## Installation

### Curl

`install.sh` installe aussi `curl`, `ca-certificates` et `tar`, télécharge la branche `main`, et écrit les sources dans `/opt/high-fortress-user/src`. Il lance ensuite `scripts/configure.sh`. Si `global.conf` contient déjà `HF_PREPARED=1`, si `secrets.conf` existe, et si `scripts/configure.sh --check` passe, il lance `scripts/run.sh` à la place.

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git swaks tar
curl -fsSL https://raw.githubusercontent.com/palarchsys/high-fortress-user/main/install.sh | sudo bash
```

### Clone

Le clone reste dans le répertoire créé par `git clone`. `sudo ./hf configure` s'exécute dans ce répertoire. L'installeur curl est la commande qui copie les sources vers `/opt/high-fortress-user/src`.

```bash
git clone https://github.com/palarchsys/high-fortress-user
cd high-fortress-user
sudo ./hf configure
```

## Action de configure.sh

`sudo ./hf configure` pose les questions ci-dessous, écrit `global.conf` en mode `644` et `secrets.conf` en mode `600` en root, puis lance `scripts/run.sh`. `secrets.conf` ne quitte pas la machine.

| Question         | Réponse attendue                                                                                                                                                                                | Entrée conserve                                                           |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| Jeton Ubuntu Pro | Lettres et chiffres, de 6 à 100, sans espace. Obligatoire.                                                                                                                                      | Un jeton déjà enregistré. Un premier passage n'a pas de jeton enregistré. |
| Activer          | `Y` ou `y` active les alertes. `n` ou `non` les coupe. Toute autre réponse affiche `Répondez Y ou n.`                                                                                           | Rien. La question n'a pas de défaut.                                      |
| Serveur          | `hôte:port`, par exemple `smtp-mail.outlook.com:587`. Sans crochets. Demandé seulement si les alertes sont activées.                                                                            | Rien au premier passage.                                                  |
| Login            | Une adresse e-mail.                                                                                                                                                                             | Rien au premier passage.                                                  |
| Password         | Le mot de passe d'application du fournisseur, de 8 à 128 caractères. Les espaces sont retirés. Les guillemets, `$`, `\` et l'apostrophe inverse sont refusés. Jamais le mot de passe du compte. | Rien. Une seconde ligne demande la confirmation.                          |
| From             | Une adresse e-mail. `WATCHDOG_MAIL` reçoit la même adresse.                                                                                                                                     | Rien au premier passage.                                                  |
| Mode test        | `0` ou `1`.                                                                                                                                                                                     | La valeur actuelle de `MODE_TEST`. Le défaut livré est `[1]`.             |

Lorsque les alertes sont activées, `swaks` doit recevoir un `250` SMTP. La ligne de succès est `Essai d'envoi accepté.` `HF_MAIL_ALERTS` passe à `1`. Lorsque les alertes sont coupées, la ligne de succès est `Alertes e-mail coupées. Les contrôles partiront sans envoi.` et les variables de courrier sont vidées.

Les valeurs qui ne sont pas demandées sont écrites depuis `hfu_config_set_builtin_defaults` et depuis le `global.conf` livré. Elles sont listées dans [configuration.md](configuration.md). Aucun mot de passe aléatoire n'est généré.

## Logiciels et services installés

| Nom                                             | Origine                                                                                 | Rôle                                                                                                                                     |
| ----------------------------------------------- | --------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| openssh-server                                  | Ubuntu archive                                                                          | Serveur SSH. La connexion root est refusée. L'authentification par mot de passe reste activée.                                           |
| ufw                                             | Ubuntu archive                                                                          | Pare-feu de l'hôte.                                                                                                                      |
| fail2ban                                        | Ubuntu archive                                                                          | Bannit les échecs d'authentification répétés.                                                                                            |
| auditd                                          | Ubuntu archive                                                                          | Écrit les règles d'audit des chemins choisis.                                                                                            |
| rkhunter                                        | Ubuntu archive                                                                          | Contrôle rootkit et propriétés de fichiers.                                                                                              |
| chkrootkit                                      | Ubuntu archive                                                                          | Contrôle rootkit. Le binaire est `/usr/sbin/chkrootkit`.                                                                                 |
| clamav                                          | Ubuntu archive                                                                          | Analyse à l'accès et analyse au démarrage.                                                                                               |
| crowdsec                                        | https://packagecloud.io/crowdsec/crowdsec/any any main                                  | Décisions de sécurité locales.                                                                                                           |
| debsums                                         | Ubuntu archive                                                                          | Sommes de contrôle des fichiers des paquets.                                                                                             |
| unbound                                         | Ubuntu archive                                                                          | Résolveur DNS local sur `127.0.0.1` et `::1`, port 53.                                                                                   |
| apparmor                                        | Ubuntu archive, plus `service/apparmor/userns.sh`                                       | Profils de la distribution, plus des profils userns pour Brave, Discord, Thunderbird, et Steam lorsqu'aucun profil ne couvre déjà Steam. |
| aide                                            | Ubuntu archive                                                                          | Base d'intégrité `/var/lib/aide/aide.db`.                                                                                                |
| unattended-upgrades                             | Ubuntu archive                                                                          | Origines de sécurité et l'origine Thunderbird. `Automatic-Reboot` vaut `false`.                                                          |
| postfix                                         | Ubuntu archive, only when `HF_MAIL_ALERTS=1`                                            | Envoie le courrier d'alerte.                                                                                                             |
| lynis                                           | https://packages.cisofy.com/community/lynis/deb/ stable main                            | Audit de durcissement. La clé est `https://packages.cisofy.com/keys/cisofy-software-public.key`.                                         |
| ubuntu-pro-client                               | Ubuntu archive                                                                          | Attache le jeton Ubuntu Pro.                                                                                                             |
| brave-browser                                   | https://brave-browser-apt-release.s3.brave.com/brave-browser.sources                    | Navigateur.                                                                                                                              |
| thunderbird                                     | https://packages.mozilla.org/apt suite thunderbird-deb                                  | Client de courrier des paquets Mozilla, pas le snap.                                                                                     |
| keepassxc                                       | Ubuntu archive                                                                          | Base de mots de passe.                                                                                                                   |
| discord                                         | https://discord.com/api/download?platform=linux&format=deb                              | Client Discord.                                                                                                                          |
| Vencord                                         | https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli-linux | Installé dans le client Discord par `service/desktop/install.sh`.                                                                        |
| acct, sysstat, libpam-pwquality                 | Ubuntu archive                                                                          | Comptabilité des processus, statistiques d'activité, qualité des mots de passe.                                                          |
| rng-tools-debian, haveged                       | Ubuntu archive                                                                          | Sources d'entropie.                                                                                                                      |
| apt-listchanges, needrestart, apt-show-versions | Ubuntu archive                                                                          | Avis de changements de paquets et contrôles de redémarrage.                                                                              |

## Ce que la machine fait après l'installation

| Sujet     | Comportement                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Pare-feu  | `ufw default deny incoming`, `ufw default allow outgoing`, `ufw default allow routed`. La boucle locale est autorisée dans les deux sens. Aucune autre règle entrante n'est ajoutée.                                                                                                                                                                                                                                                                                                                           |
| DNS       | Unbound écoute sur `127.0.0.1` et `::1`. systemd-resolved et NetworkManager sont dirigés vers ce résolveur. Le DNS IPv6 reste activé (`do-ip6: yes`).                                                                                                                                                                                                                                                                                                                                                          |
| SSH       | `PermitRootLogin no`. `PasswordAuthentication yes`. `PubkeyAuthentication yes`. Bannière `/etc/ssh/sshd_banner`. `MaxAuthTries 4`.                                                                                                                                                                                                                                                                                                                                                                             |
| Noyau     | `/etc/sysctl.d/90-high-fortress-user.conf` est copié vers `/etc/sysctl.d/99-zzz-high-fortress-user.conf`. IPv6 reste activé. Les redirections IPv6 et le source routing sont refusés. Les user namespaces restent activés. `dccp`, `sctp`, `rds` et `tipc` sont en liste noire. Les systèmes de fichiers inutilisés sont en liste noire. Les core dumps sont à 0. `PWQUALITY_MINLEN` vaut 12.                                                                                                                  |
| AppArmor  | Les profils de la distribution restent. `service/apparmor/userns.sh` ajoute `hfu-brave`, `hfu-discord`, `hfu-thunderbird`, et `hfu-steam` lorsque Steam n'est pas déjà couvert.                                                                                                                                                                                                                                                                                                                                |
| Contrôles | `hfu-boot-scan.timer` lance `boot-scan.sh` 2 minutes après le démarrage (`OnBootSec=2min`, `Persistent=false`). La passe lance AIDE, rkhunter, chkrootkit, ClamAV et debsums. `Nice` vaut `WATCHDOG_LIMIT_NICE` (19), `IOSchedulingClass=idle`, `CPUQuota` vaut `WATCHDOG_CPU_LIMIT` (20 %). `/etc/cron.d/high-fortress-user` ne contient que `SHELL` et `PATH`. La crontab de l'utilisateur n'est pas modifiée. Le courrier part seulement lorsqu'un contrôle trouve quelque chose et que `HF_MAIL_ALERTS=1`. |
| Lynis     | `LYNIS_MIN_SCORE` vaut 80. `verify/workstation.sh` accepte un `hardening_index` supérieur ou égal à ce seuil.                                                                                                                                                                                                                                                                                                                                                                                                  |
| Journaux  | Les journaux d'installation sont `<source>/logs/install-YYYYMMDD-HHMMSS-user/`. Les journaux de sécurité sont `/opt/high-fortress-user/cron/security_logs/`. Le stockage journald est persistant.                                                                                                                                                                                                                                                                                                             |
| Paquets   | Les snaps Firefox et Thunderbird sont retirés. `snapd` est conservé. Le paquet `firefox` est bloqué. Sur amd64, l'architecture i386 est activée. Steam n'est pas installé par ce programme.                                                                                                                                                                                                                                                                                                                    |

## E-mails d'alerte

Le courrier part seulement si `HF_MAIL_ALERTS=1`, si `WATCHDOG_MAIL` est défini, et si `/opt/high-fortress-user/cron/bin/send.sh` est exécutable. Un contrôle propre n'envoie pas de courrier. Si une ligne du journal est inconnue, ne lancez pas la commande. Gardez le courrier.

### AIDE

Le message contient la ligne de résumé et un extrait du journal, puis la note et le bloc de commande. Le chemin du journal dans le courrier est le fichier réel. La forme est `/opt/high-fortress-user/cron/security_logs/aide-YYYYMMDD-HHMMSS.log`.

```bash
sudo bash /opt/high-fortress-user/bin/aide-refresh-db.sh
```

La commande reconstruit la base AIDE à partir du disque actuel. La ligne de succès est `Base de référence AIDE enregistrée.`

### chkrootkit

Le message contient le résumé et l'extrait du journal, puis la note et la commande. L'exemple ci-dessous montre la forme. Le courrier contient le chemin réel.

```bash
sudo bash /opt/high-fortress-user/bin/chkrootkit-ignore-log.sh '/opt/high-fortress-user/cron/security_logs/chkrootkit-YYYYMMDD-HHMMSS.log'
```

La commande enregistre les lignes de ce journal dans `/opt/high-fortress-user/cron/chkrootkit.local.ignore`. La ligne de succès est `Aucune nouvelle détection à enregistrer.` lorsqu'il n'y a rien de nouveau, ou `N détection(s) enregistrée(s) dans /opt/high-fortress-user/cron/chkrootkit.local.ignore`.

### debsums

Le message contient le résumé et l'extrait du journal, puis la note et la commande. L'exemple ci-dessous montre la forme. Le courrier contient le chemin réel.

```bash
sudo bash /opt/high-fortress-user/bin/debsums-ignore-log.sh '/opt/high-fortress-user/cron/security_logs/debsums-YYYYMMDD-HHMMSS.log'
```

La commande enregistre les lignes de ce journal dans `/opt/high-fortress-user/cron/debsums.local.ignore`. La ligne de succès est `Aucune nouvelle détection à enregistrer.` ou `N détection(s) enregistrée(s) dans /opt/high-fortress-user/cron/debsums.local.ignore`. Une ligne pour `/var/lib/rkhunter/db/mirrors.dat` est retirée avant le courrier seulement si son SHA-256 actuel est égal à `/opt/high-fortress-user/cron/rkhunter-mirrors.sha256`. Tout autre contenu reste dans le courrier. N'ignorez pas le fichier entier.

### ClamAV à l'accès

Le message contient la signature, le nom du fichier, le chemin d'origine et le chemin de quarantaine, puis la note et une commande `sudo ls`. La commande est construite pour le fichier en quarantaine nommé dans le courrier. Un fichier dont le nom correspond à `.clamav-quarantine-lock.*` n'envoie pas de courrier. Le script sort en 0 avant le journal et avant `log_alert`.

```bash
sudo ls -la -- /var/lib/clamav/quarantine/<file>
```

L'exemple montre la forme. Le courrier contient le chemin réel, cité. La commande liste ce fichier et ne le remet pas en place. `ls` affiche l'entrée. Il n'y a pas de ligne de succès de l'installeur.

### Analyse ClamAV au démarrage

Le message contient le résumé et l'extrait du journal. Ce courrier n'ajoute pas de bloc de commande. La forme du journal est `/opt/high-fortress-user/cron/security_logs/clamav-YYYYMMDD-HHMMSS.log`.

### rkhunter

Le message contient le résumé et l'extrait du journal. Ce courrier n'ajoute pas de bloc de commande. Un écart d'empreinte ajoute la ligne `mirrors.dat modifié hors rkhunter --update`. Cette ligne n'est pas une commande. La forme du journal est `/opt/high-fortress-user/cron/security_logs/rkhunter-YYYYMMDD-HHMMSS.log`.

## Commandes après l'installation

Lancez ces commandes depuis le répertoire des sources (`/opt/high-fortress-user/src` après l'installeur curl, ou le répertoire du clone).

### hf check

```bash
sudo ./hf check
```

Contrôle `global.conf` et `secrets.conf`. La ligne de succès est `Configuration conforme`. `secrets.conf` est en mode `600`, donc `sudo` est requis pour le lire.

### hf run

```bash
sudo ./hf run
```

Lance l'installation à partir des fichiers préparés. L'installeur refuse de démarrer lorsque le contrôle ne passe pas.

### verify/alerts.sh

```bash
sudo bash verify/alerts.sh
```

Contrôle le timer de démarrage, ClamAV à l'accès, et le chemin du courrier. Sans `--no-send`, une sonde part lorsque les alertes sont activées. Le sujet se termine par `Contrôle`. La ligne de succès est `Résultat : OK`.

```bash
sudo bash verify/alerts.sh --no-send
```

Le même contrôle sans envoyer la sonde.

### verify/workstation.sh

```bash
sudo bash verify/workstation.sh "$PWD"
```

Lance la vérification du poste. La ligne de clôture a la forme `Check : N OK / N WARN / N FAIL`.

### hf lynis

```bash
sudo ./hf lynis
```

Lance `lynis audit system --quick --no-colors` et écrit le rapport sous `<source>/logs/lynis-<stamp>/`.

### Base AIDE

```bash
sudo bash /opt/high-fortress-user/bin/aide-refresh-db.sh
```

Reconstruit `/var/lib/aide/aide.db`. La ligne de succès est `Base de référence AIDE enregistrée.`

### Empreinte des miroirs rkhunter

```bash
sudo bash /opt/high-fortress-user/cron/bin/record-mirrors.sh save
```

Écrit le SHA-256 de `/var/lib/rkhunter/db/mirrors.dat` dans `/opt/high-fortress-user/cron/rkhunter-mirrors.sha256` en mode `600`. `rkhunter.sh` enregistre cette empreinte seulement après un `rkhunter --update` qui retourne 0 ou 2.

## Fichiers détaillés

| Sujet                              | Page                                 |
| ---------------------------------- | ------------------------------------ |
| Variables générales et par service | [configuration.md](configuration.md) |
| Outils de surveillance             | [surveillance.md](surveillance.md)   |
| Arborescence installée             | [architecture.md](architecture.md)   |
| Fichiers installés                 | [files.md](files.md)                 |
| Journaux                           | [logs.md](logs.md)                   |
