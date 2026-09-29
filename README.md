# High-Fortress User

High-Fortress User prépare un poste Ubuntu 26.04 pour un usage quotidien. Il active les mises à jour de sécurité Ubuntu Pro, règle le pare-feu et les contrôles du système, installe les logiciels du bureau, puis envoie un e-mail de confirmation.

Le compte créé pendant l'installation d'Ubuntu reste tel quel : le nom, le mot de passe, le dossier personnel et l'interpréteur de commandes ne changent pas.

## Avant de commencer

Il vous faut :

- un ordinateur sous Ubuntu 26.04, de préférence une installation neuve, avec une session graphique et une connexion à Internet ;
- le droit d'administration (`sudo`) ;
- un compte [Ubuntu Pro](https://ubuntu.com/pro) et son jeton, copié depuis le [tableau de bord](https://ubuntu.com/pro/dashboard) ;
- une adresse GMAIL ;
- un Mot de passe d'application GMAIL ;

## Ubuntu Pro

Le jeton rattache l'ordinateur à votre compte Ubuntu Pro. Le programme active ensuite :

| Élément | Rôle |
|---------|------|
| ESM Infra | Correctifs de sécurité du dépôt principal, au-delà du support standard |
| ESM Apps | Correctifs de sécurité du dépôt universe |
| Livepatch | Certains correctifs du noyau, appliqués sans redémarrage |
| Mises à jour automatiques | Installation quotidienne des correctifs de sécurité Ubuntu, ESM et Thunderbird |

Les mises à jour ordinaires, hors sécurité, restent proposées par la mise à jour logicielle d'Ubuntu. Aucun redémarrage n'est lancé automatiquement.

## Mot de passe d'application GMAIL

Gmail refuse le mot de passe habituel du compte pour un programme comme celui-ci. Il faut un mot de passe d'application : 16 lettres créées par Google, utilisées seulement pour l'envoi des alertes.

1. Ouvrez la [validation en deux étapes](https://myaccount.google.com/signinoptions/two-step-verification) et activez-la si ce n'est pas déjà fait. Sans elle, la page des mots de passe d'application reste fermée.
2. Ouvrez [Mots de passe des applications](https://myaccount.google.com/apppasswords).
3. Donnez le nom `High-Fortress User`, puis créez le mot de passe.
4. Google affiche 16 lettres, souvent en groupes de 4. Copiez-les sans les espaces.
5. Collez-les dans `configure.sh` lorsque le mot de passe SMTP est demandé.

Le mot de passe du compte Ubuntu et celui de Gmail dans le navigateur ne changent pas. Le poste ne reçoit pas le courrier : il ne fait qu'envoyer les alertes vers Gmail.

Guide Google : [Se connecter avec des mots de passe d'application](https://support.google.com/accounts/answer/185833).

## Installation

Prévoyez du temps : le téléchargement des paquets et le calcul de la base d'intégrité des fichiers prennent plusieurs minutes. Laissez la session ouverte jusqu'au message de fin.

Cette commande installe curl, télécharge le programme dans `/opt/high-fortress-user/src`, puis lance la configuration :

```bash
sudo apt-get install git curl -y
curl -fsSL https://raw.githubusercontent.com/palarchsys/high-fortress-user/main/install.sh | sudo bash
```

Les cinq questions portent sur le jeton Ubuntu Pro et l'e-mail GMAIL. Un secret s'affiche en astérisques, puis une ligne Confirmation redemande la même saisie. Entrée conserve une valeur déjà enregistrée. L'installation démarre dès que les réponses sont acceptées.

Pour recontrôler les fichiers sans relancer l'installation : `sudo bash /opt/high-fortress-user/src/configure.sh --check`.

Si vous avez déjà cloné le dossier vous-même :

```bash
git clone https://github.com/palarchsys/high-fortress-user.git
cd high-fortress-user
sudo bash configure.sh
```

`secrets.conf` contient le jeton et le mot de passe d'envoi. Il reste sur la machine, lisible par root seulement. Ne le copiez pas dans un message, un ticket ou un dépôt public.

## Ce que configure.sh demande

| Question | Ce qu'il faut répondre |
|----------|------------------------|
| Jeton Ubuntu Pro | La valeur affichée sur le tableau de bord Ubuntu Pro, sans espace |
| Adresse qui envoie | Votre adresse GMAIL complète |
| Mot de passe SMTP | Le mot de passe d'application à 16 lettres, sans les espaces |
| Serveur SMTP | `[smtp.gmail.com]:587` |
| Adresse qui reçoit les alertes | Une adresse GMAIL, la même ou une autre |

## Déroulement de l'installation

`run.sh` avance dans cet ordre.

1. Les snaps Firefox et Thunderbird sont retirés. `snapd` reste installé, ainsi que les autres snaps. Le paquet Firefox est bloqué pour qu'il ne revienne pas à la place de Brave.
2. Les réglages du poste, la messagerie locale (Postfix) et SSH.
3. La pile de sécurité : pare-feu, Fail2Ban, audit, rkhunter, chkrootkit, ClamAV, CrowdSec, debsums, AppArmor, AIDE, mises à jour automatiques, puis les contrôles planifiés.
4. Brave, Thunderbird (dépôt Mozilla), KeePassXC, Discord et Vencord, puis les profils dont ces programmes ont besoin pour leur bac à sable.
5. Retrait des paquets résiduels, vérification du poste, enregistrement de la base AIDE, e-mail de test.

## Logiciels installés

| Logiciel | Origine |
|----------|---------|
| Brave | Dépôt apt publié sur [brave.com/linux](https://brave.com/linux/). C'est le navigateur du poste. Firefox est retiré. |
| Thunderbird | Dépôt apt Mozilla, suite `thunderbird-deb` |
| KeePassXC | Dépôt Ubuntu |
| Discord | Paquet `.deb` publié sur [discord.com/download](https://discord.com/download) |
| Vencord | Installeur officiel, [vencord.dev](https://vencord.dev/download/), appliqué à ce Discord |

## Ce que le poste fait après l'installation

| Sujet | Comportement |
|-------|----------------|
| Pare-feu | Les connexions entrantes sont refusées. Les connexions sortantes sont autorisées. |
| SSH | La connexion root est interdite. Le mot de passe de votre compte habituel reste accepté. Le nombre d'essais est limité. Fail2Ban bloque une adresse après plusieurs échecs. |
| Comptes | Les comptes déjà créés restent tels quels. Un nouveau mot de passe, le jour où vous en choisissez un, doit respecter une longueur minimale. |
| Noyau | Les paquets réseau douteux sont filtrés, les vidages mémoire des programmes sont désactivés, les adresses du noyau sont masquées. IPv6 reste actif. |
| AppArmor | Le réglage d'Ubuntu est conservé. Un profil est ajouté seulement lorsqu'un logiciel en a besoin pour son bac à sable et qu'il n'en a pas déjà un. |
| ClamAV | En continu sur les dossiers Téléchargements et Bureau, jusqu'à 25 Mo par fichier. Une installation lancée par l'administrateur n'est pas retenue. À chaque démarrage, un parcours complémentaire couvre le reste de `/tmp`, `/home` et `/opt`, en dehors de ces deux dossiers. |
| Contrôles au démarrage | AIDE, rkhunter, chkrootkit, le parcours ClamAV et debsums. Ils utilisent au plus 20 % du processeur et une priorité basse, deux minutes après le démarrage. |
| Lynis | Lancé une fois à la fin de l'installation. Le score doit être d'au moins 80. Il ne fait pas partie des contrôles au démarrage. |
| CrowdSec | Lit les journaux SSH et système, et bloque l'adresse attaquante dans le pare-feu pendant 24 heures. |
| E-mail | Chaque alerte part vers l'adresse Gmail indiquée dans `configure.sh`. |
| Journaux | `/var/log/high-fortress-user/` et `/opt/high-fortress-user/cron/`. |

## E-mail AIDE

Au démarrage, AIDE compare le disque à la photo prise à la fin de l'installation. Un fichier ajouté, retiré ou modifié produit un e-mail.

L'e-mail contient d'abord le journal. En dessous, un second bloc donne la commande complète. Copiez-la telle quelle : rien n'est à modifier.

```bash
sudo bash /opt/high-fortress-user/bin/aide-refresh-db.sh
```

La commande recalcule la photo à partir du disque actuel. Le calcul peut prendre plusieurs minutes. Elle affiche `Base de référence AIDE enregistrée.` lorsqu'elle a réussi. Le démarrage suivant ne signale plus ces changements.

Si une ligne du journal vous est inconnue, ne lancez pas cette commande. Conservez l'e-mail et relisez le chemin indiqué.

L'e-mail de fin d'installation est un essai d'envoi. Son objet indique que l'installation s'est terminée. Il ne contient pas ce second bloc.

## E-mail chkrootkit

Au démarrage, chkrootkit cherche des signes connus de compromission. Une ligne absente de la liste d'exclusion produit un e-mail.

L'e-mail contient d'abord le journal. En dessous, un second bloc donne la commande complète, avec le nom réel du journal de cette alerte. Copiez-la telle quelle : rien n'est à modifier.

La commande enregistre ces lignes dans `/opt/high-fortress-user/cron/chkrootkit.local.ignore`. Elle affiche le nombre de détections enregistrées. Le démarrage suivant ne signale plus ces lignes exactes. Une ligne différente, par exemple un autre numéro de processus, produit un nouvel e-mail. Une réinstallation du poste conserve ce fichier.

Si une ligne du journal vous est inconnue, ne lancez pas cette commande. Conservez l'e-mail et relisez le chemin indiqué.

## E-mail debsums

Au démarrage, debsums compare les fichiers des paquets Ubuntu à leurs empreintes. Un fichier modifié ou manquant produit un e-mail.

L'e-mail contient d'abord le journal. En dessous, un second bloc donne la commande complète, avec le nom réel du journal de cette alerte. Copiez-la telle quelle : rien n'est à modifier.

La commande enregistre ces lignes dans `/opt/high-fortress-user/cron/debsums.local.ignore`. Elle affiche le nombre de détections enregistrées. Le démarrage suivant ne signale plus ces lignes exactes. Une ligne différente, par exemple un autre fichier, produit un nouvel e-mail. Une réinstallation du poste conserve ce fichier.

Si une ligne du journal vous est inconnue, ne lancez pas cette commande. Conservez l'e-mail et relisez le chemin indiqué.

## Après l'installation

Un redémarrage est souvent utile lorsque le noyau ou des bibliothèques ont été mis à jour. Ouvrez ensuite Brave, Discord et KeePassXC depuis le menu des applications. Discord démarre avec Vencord.

Pour relire l'état du poste :

```bash
sudo bash /opt/high-fortress-user/src/verify/workstation.sh
```

Après un redémarrage, ce script relit les services et les journaux du démarrage. La sortie est prévue pour être copiée :

```bash
sudo bash /opt/high-fortress-user/src/verify/boot.sh
```

Lynis a déjà tourné à la fin de l'installation. Pour le relancer vous-même :

```bash
sudo bash /opt/high-fortress-user/src/lynis.sh
```

## En cas de blocage

| Message | Que faire |
|---------|-----------|
| `Configuration conforme` est absent | Relancer `configure.sh`, confirmer avec `o`, puis `--check` |
| Le jeton est refusé | Le recopier depuis le tableau de bord Ubuntu Pro, sans espace |
| Ubuntu Pro n'attache pas la machine | Vérifier le jeton et la connexion, puis relancer `sudo bash run.sh` |
| Le système n'est pas Ubuntu 26.04 | Le programme ne continue pas |
| L'empreinte de la clé Mozilla est inattendue | Vérifier la connexion, puis relancer `sudo bash run.sh` |
| L'e-mail de test ne part pas | Vérifier l'adresse Gmail, le mot de passe d'application sans espaces, et le serveur `[smtp.gmail.com]:587` |
| La base AIDE n'est pas générée | Lire `/var/log/high-fortress-user/aide-init.log`, puis relancer `sudo bash /opt/high-fortress-user/bin/aide-refresh-db.sh` une fois le message d'erreur compris |

Les journaux de l'installation sont dans `/var/log/high-fortress-user/`.
