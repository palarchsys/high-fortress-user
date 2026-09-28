# High-Fortress User

Ce programme prépare un poste **Ubuntu 26.04** tout juste installé : il active les mises à jour de sécurité Ubuntu Pro, applique un durcissement compatible avec un usage quotidien, puis installe les logiciels listés plus bas.

Le compte créé pendant l'installation d'Ubuntu n'est pas modifié : ni le mot de passe, ni le nom, ni le dossier personnel.

## Ce qu'il faut avant de commencer

- Un ordinateur sous **Ubuntu 26.04**, de préférence une installation neuve, avec une session graphique et une connexion Internet.
- Le droit d'administration (`sudo`).
- Un compte [Ubuntu Pro](https://ubuntu.com/pro). L'offre personnelle permet de rattacher plusieurs machines. Le jeton se copie depuis le [tableau de bord](https://ubuntu.com/pro/dashboard).
- Une **adresse Gmail**. Cette version envoie les alertes uniquement par Gmail (`@gmail.com` ou `@googlemail.com`) et le serveur `[smtp.gmail.com]:587`. Une autre boîte (Outlook, Orange, etc.) est refusée.

Le programme s'arrête si le système n'est pas Ubuntu 26.04, ou si l'adresse n'est pas une adresse Gmail.

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

`configure.sh` demande le jeton Ubuntu Pro, l'adresse Gmail, le mot de passe d'application, le serveur SMTP et l'adresse qui reçoit les alertes. La saisie des secrets est masquée. Une confirmation `o` écrit les fichiers. `--check` affiche `Configuration conforme` quand ces fichiers sont acceptés. `run.sh` fait l'installation et ne repose pas les questions.

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

## Mot de passe d'application Gmail

Postfix envoie les alertes (AIDE, ClamAV, rkhunter, chkrootkit, debsums, audit) depuis le poste. Gmail n'accepte pas le mot de passe habituel du compte : il faut un **mot de passe d'application**, une suite de 16 lettres créée par Google.

1. Ouvrez la [validation en deux étapes](https://myaccount.google.com/signinoptions/two-step-verification) et activez-la si ce n'est pas déjà le cas. Sans cette étape, la page des mots de passe d'application reste fermée.
2. Ouvrez [Mots de passe des applications](https://myaccount.google.com/apppasswords).
3. Dans « Nom de l'application », écrivez `High-Fortress User`, puis créez le mot de passe.
4. Google affiche 16 lettres, souvent par groupes de 4. Copiez-les **sans les espaces**.
5. Dans `configure.sh` :
   - adresse qui envoie : votre adresse Gmail complète (`@gmail.com`) ;
   - mot de passe : ces 16 lettres ;
   - serveur SMTP : `[smtp.gmail.com]:587` (la seule valeur acceptée) ;
   - adresse qui reçoit : une adresse Gmail, la même ou une autre.

Le mot de passe d'application ne sert qu'à Postfix. Le mot de passe du compte Ubuntu et celui de Gmail dans le navigateur restent inchangés. Postfix n'écoute pas sur le réseau : il ne fait que relayer vers Gmail.

Guide Google : [Se connecter avec des mots de passe d'application](https://support.google.com/accounts/answer/185833).

## Machines virtuelles

Le programme installe QEMU/KVM et active `libvirtd.service`. Sur Ubuntu 26.04, le réseau NAT des invités (`virbr0`) est inclus dans ce démon. L'unité `virtnetworkd.service` est activée lorsqu'elle est fournie par le paquet ; cette version d'Ubuntu ne la livre pas à part. Le paquet ajoute le groupe `libvirt` aux comptes qui sont déjà dans `sudo`, ce qui permet de piloter les machines virtuelles. Le nom du compte, son dossier et son mot de passe ne changent pas.

## Logiciels installés à la fin

| Logiciel | Origine |
|----------|---------|
| Brave | Dépôt apt officiel, [brave.com/linux](https://brave.com/linux/). Firefox est retiré. |
| Telegram | Paquet snap officiel `telegram-desktop` |
| Discord | Dernier paquet `.deb` publié sur [discord.com/download](https://discord.com/download) |
| Vencord | Installeur officiel, [vencord.dev](https://vencord.dev/download/), appliqué à ce Discord |
| Thunderbird | Dépôt Ubuntu |
| KeePassXC | Dépôt Ubuntu |
| QEMU | Dépôt Ubuntu, paquet `qemu-system-x86`, avec libvirt |

Brave, Telegram, Discord et Vencord suivent le canal de leur éditeur. Thunderbird, KeePassXC et QEMU (`qemu-system-x86`) suivent les paquets Ubuntu. Le paquet Discord officiel ne contient que le téléchargeur : le programme récupère le client dans le dossier personnel, puis Vencord s'y installe. Firefox et Steam ne sont pas installés ici ; le pare-feu laisse sortir leur trafic, et l'architecture 32 bits est activée pour Steam.

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

Un redémarrage est souvent utile, surtout si le noyau ou des bibliothèques ont été mis à jour. Ouvrez ensuite Brave, Telegram, Discord et KeePassXC depuis le menu des applications. Discord démarre avec Vencord. Le navigateur du poste est Brave.

Un courriel de test part à la fin, vers l'adresse des alertes. Son objet indique que l'installation s'est terminée et qu'il s'agit d'un essai d'envoi.

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
