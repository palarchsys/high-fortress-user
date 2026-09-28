# High-Fortress User

Ce programme prépare un poste **Ubuntu 26.04** tout juste installé : il active les mises à jour de sécurité Ubuntu Pro, applique un durcissement compatible avec un usage quotidien, puis installe les logiciels listés plus bas.

Le compte créé pendant l'installation d'Ubuntu n'est pas modifié : ni le mot de passe, ni le nom, ni le dossier personnel.

## Ce qu'il faut avant de commencer

- Un ordinateur sous **Ubuntu 26.04**, de préférence une installation neuve, avec une session graphique et une connexion Internet.
- Le droit d'administration (`sudo`).
- Un compte [Ubuntu Pro](https://ubuntu.com/pro). L'offre personnelle permet de rattacher plusieurs machines. Le jeton se copie depuis le [tableau de bord](https://ubuntu.com/pro/dashboard).

Le programme s'arrête si le système n'est pas Ubuntu 26.04.

## Installation

La commande suivante télécharge le programme depuis GitHub et le place dans `/opt/high-fortress-user/src` :

```bash
curl -fsSL https://raw.githubusercontent.com/palarchsys/high-fortress-user/main/install.sh | sudo bash
```

La première fois, elle s'arrête : le jeton Ubuntu Pro n'est pas encore enregistré. Enchaînez avec :

```bash
sudo bash /opt/high-fortress-user/src/configure.sh
sudo bash /opt/high-fortress-user/src/configure.sh --check
sudo bash /opt/high-fortress-user/src/run.sh
```

`configure.sh` demande le jeton deux fois (la saisie est masquée), puis demande une confirmation `o` avant d'écrire les fichiers. `--check` affiche `Configuration conforme` quand ces fichiers sont acceptés. `run.sh` fait l'installation et ne repose pas la question.

Autre branche ou autre dossier :

```bash
curl -fsSL https://raw.githubusercontent.com/palarchsys/high-fortress-user/main/install.sh | sudo HF_BRANCH=main bash
curl -fsSL https://raw.githubusercontent.com/palarchsys/high-fortress-user/main/install.sh | sudo HF_INSTALL_ROOT=/opt/high-fortress-user/src bash
```

### Depuis un clone

```bash
git clone https://github.com/palarchsys/high-fortress-user.git
cd high-fortress-user
bash configure.sh
bash configure.sh --check
sudo bash run.sh
```

`secrets.conf` contient le jeton. Il reste sur la machine, en lecture pour root seulement. Ne le publiez pas.

## Ubuntu Pro et mises à jour de sécurité

Le jeton rattache l'ordinateur au compte Ubuntu Pro. Le programme active ensuite :

| Élément | Rôle |
|---------|------|
| ESM Infra | Correctifs de sécurité des paquets du dépôt principal, au-delà du support standard |
| ESM Apps | Correctifs de sécurité des paquets du dépôt universe |
| Livepatch | Certains correctifs du noyau, appliqués sans redémarrage |
| Mises à jour automatiques | Installation quotidienne des correctifs de sécurité Ubuntu et ESM |

Les mises à jour ordinaires (hors sécurité) ne sont pas installées toutes seules : elles restent proposées par la mise à jour logicielle d'Ubuntu. Aucun redémarrage n'est lancé automatiquement.

## Logiciels installés à la fin

| Logiciel | Origine |
|----------|---------|
| Brave | Dépôt apt officiel, [brave.com/linux](https://brave.com/linux/) |
| Telegram | Paquet snap officiel `telegram-desktop` |
| Discord | Dernier paquet `.deb` publié sur [discord.com/download](https://discord.com/download) |
| Vencord | Installeur officiel, [vencord.dev](https://vencord.dev/download/), appliqué à ce Discord |
| Thunderbird | Dépôt Ubuntu |
| KeePassXC | Dépôt Ubuntu |

Brave, Telegram, Discord et Vencord suivent le canal de leur éditeur. Thunderbird et KeePassXC suivent les paquets Ubuntu. Firefox, Steam et QEMU ne sont pas installés par ce programme ; s'ils sont déjà là, ou si vous les ajoutez ensuite, le durcissement leur laisse l'accès réseau sortant, les espaces de noms utilisateur et, pour Steam, les bibliothèques 32 bits.

## Ce que le durcissement règle

| Sujet | Réglage |
|-------|---------|
| Pare-feu | Connexions entrantes refusées, sorties autorisées. Le réseau des machines virtuelles libvirt peut traverser le poste |
| SSH | Root interdit, mot de passe du compte habituel conservé, nombre d'essais limité. Fail2Ban bloque une adresse après plusieurs échecs |
| Comptes | Les comptes déjà créés restent tels quels. Un nouveau mot de passe, le jour où vous en choisissez un, doit respecter une longueur minimale |
| Noyau | Filtrage des paquets douteux, pas de vidage mémoire des programmes, adresses du noyau masquées. IPv6 reste actif |
| Contrôle d'accès | AppArmor reste celui d'Ubuntu. Un profil est ajouté seulement lorsqu'un logiciel en a besoin pour son bac à sable et qu'il n'en a pas déjà un |
| Fichiers système | AIDE, auditd, rkhunter, chkrootkit, debsums et ClamAV surveillent le système. ClamAV ne scanne pas chaque fichier à l'ouverture |
| Journaux | Conservés sur le disque, dans `/var/log/high-fortress-user/` et `/opt/high-fortress-user/cron/` |

Les dépôts APT déjà configurés ne sont pas remplacés. Deux dépôts sont ajoutés : Lynis (outil de contrôle) et Brave.

## Après l'installation

Un redémarrage est souvent utile, surtout si le noyau ou des bibliothèques ont été mis à jour. Ouvrez ensuite Brave, Telegram, Discord et KeePassXC depuis le menu des applications. Discord démarre avec Vencord.

La vérification relit l'état du poste :

```bash
sudo bash /opt/high-fortress-user/src/verify/workstation.sh
```

Le contrôle Lynis, plus long, s'obtient avec :

```bash
sudo bash /opt/high-fortress-user/src/lynis.sh
```

## En cas de blocage

| Message | Que faire |
|---------|-----------|
| `Configuration conforme` absent | Relancer `configure.sh`, confirmer avec `o`, puis `--check` |
| Jeton refusé | Le recopier depuis le tableau de bord Ubuntu Pro, sans espace |
| Ubuntu Pro n'attache pas la machine | Vérifier le jeton et la connexion, puis relancer `sudo bash run.sh` |
| Le système n'est pas Ubuntu 26.04 | Le programme ne continue pas |

Les journaux de l'installation sont dans `/var/log/high-fortress-user/`.
