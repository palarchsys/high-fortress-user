[README complet](README.md)

# Surveillance

## AIDE

| Service qui surveille   | Zones                                               | Ce qui part en alerte                                                 | Commande du courrier                                       |
| ----------------------- | --------------------------------------------------- | --------------------------------------------------------------------- | ---------------------------------------------------------- |
| aide.sh in boot-scan.sh | /etc/aide/aide.conf, database /var/lib/aide/aide.db | Des changements, ou un code non nul qui n'est pas un résultat propre. | `sudo bash /opt/high-fortress-user/bin/aide-refresh-db.sh` |

Les chemins volatils, les journaux, les caches et les répertoires de rapports cron sont exclus dans `service/aide/aide.conf` afin que la base ne soit pas réécrite par ces fichiers.

Le bloc du compte est ajouté après `!/home/`.

La dernière règle qui correspond l'emporte.

Les chemins surveillés sont `.ssh/authorized_keys`, `.bashrc`, `.profile`, `.bash_profile`, `.config/autostart` et `.config/systemd/user` du compte du poste.

`.ssh/known_hosts` et `.ssh/known_hosts.old` sont exclus.

## rkhunter

| Service qui surveille       | Zones                                            | Ce qui part en alerte                                                                      | Commande du courrier     |
| --------------------------- | ------------------------------------------------ | ------------------------------------------------------------------------------------------ | ------------------------ |
| rkhunter.sh in boot-scan.sh | Périmètre du paquet, plus la base de propriétés. | Avertissements, une mise à jour en échec, ou `mirrors.dat modifié hors rkhunter --update`. | Pas de bloc de commande. |

`/var/lib/rkhunter/db/mirrors.dat` n'est pas ignoré en tant que fichier. L'empreinte `/opt/high-fortress-user/cron/rkhunter-mirrors.sha256` est écrite seulement après un `rkhunter --update` qui retourne 0 ou 2. Un hash différent est une alerte. Le contrôle a lieu avant le `--update` suivant.

## chkrootkit

| Service qui surveille         | Zones                   | Ce qui part en alerte                               | Commande du courrier                                                         |
| ----------------------------- | ----------------------- | --------------------------------------------------- | ---------------------------------------------------------------------------- |
| chkrootkit.sh in boot-scan.sh | /usr/sbin/chkrootkit -q | Toute sortie restante après les listes d'exclusion. | `sudo bash /opt/high-fortress-user/bin/chkrootkit-ignore-log.sh '<journal>'` |

Les lignes connues sont dans `cron/bin/chkrootkit.ignore` et dans `cron/chkrootkit.local.ignore`. Le fichier local est rempli seulement par la commande du courrier, et seulement pour des lignes que vous reconnaissez.

## ClamAV à l'accès

| Service qui surveille           | Zones                      | Ce qui part en alerte                            | Commande du courrier               |
| ------------------------------- | -------------------------- | ------------------------------------------------ | ---------------------------------- |
| clamonacc, then clamav-event.sh | Téléchargements et Bureau. | Une vraie détection. Les verrous n'alertent pas. | `sudo ls -la -- <quarantine path>` |

| Exclusion | Règle |
| --- | --- |
| `scan-skip.paths` | Chemins acceptés seulement. |
| utilisateur `clamav` | `OnAccessExcludeUname clamav` |
| root | `OnAccessExcludeRootUID yes` |
| taille | Fichiers au-dessus de 25 Mo. |

Le fichier livré liste :

- `$HOME/.steam`
- `$HOME/.local/share/Steam`
- `$HOME/.cache`
- `$HOME/snap`
- `/var/jeux`

Brave, Thunderbird et Discord restent analysés.

Un chemin est accepté sous le home de l'utilisateur du poste, plus bas que ce home.

Un chemin est accepté sous `/var/jeux`, y compris `/var/jeux`.

| Refus | Chemins |
| --- | --- |
| racines du système | `/`, `/home`, `/opt`, `/tmp`, `/etc`, `/usr`, `/var`, `/boot`, `/root` |
| home entier | `/home/<user>` |
| répertoires à l'accès | Téléchargements, Bureau |
| parent de ces répertoires | un répertoire qui contient Téléchargements ou Bureau |
| ailleurs | un chemin hors de ce home et hors de `/var/jeux` |

Une ligne refusée est ignorée.

Elle est ajoutée à `/opt/high-fortress-user/cron/security_logs/scan-skip.log`.

`/var/jeux` est un répertoire vide, mode 750, propriétaire l'utilisateur du poste.

Ce n'est pas un compte séparé.

`.clamav-quarantine-lock.*` est un verrou de déplacement, pas un logiciel malveillant.

`clamav-event.sh` sort en 0 avant `log_alert`.

`scan-skip.sh` modifie la liste.

Les commandes sont dans le README.

La même réécriture tourne au début de `boot-scan.sh`.

Un `scan-skip.paths` déjà présent n'est pas remplacé lorsque l'installeur tourne de nouveau.

La réécriture remplace les lignes `OnAccessExcludePath` entre `# BEGIN High-Fortress User scan-skip` et `# END High-Fortress User scan-skip`.

Elle relance `clamav-daemon`, puis `clamav-clamonacc.service` ou `clamonacc.service`, lorsque ce bloc change.

Un chemin caché reçoit `ALLOWHIDDENDIR` dans `/etc/rkhunter.conf.local` lorsque la ligne manque.

Les lignes rkhunter déjà présentes restent.

## Analyse ClamAV au démarrage

| Service qui surveille     | Zones             | Ce qui part en alerte                                 | Commande du courrier     |
| ------------------------- | ----------------- | ----------------------------------------------------- | ------------------------ |
| clamav.sh in boot-scan.sh | /home, /opt, /tmp | Des infections. Une analyse propre reste silencieuse. | Pas de bloc de commande. |

L'analyse élague les répertoires de l'accès.

Elle élague les chemins acceptés de `scan-skip.paths`.

Elle élague aussi `proc`, `sys`, `dev`, `var/lib/docker`, `var/lib/libvirt`, `libvirt` et `snap-private-tmp`.

Elle lit les fichiers avec `clamscan`, dans l'unité de démarrage.

Brave, Thunderbird et Discord restent dans cette passe.

## Analyse ClamAV différée

| Service qui surveille                | Zones                                                                                                | Ce qui part en alerte                                                                                                      | Commande du courrier     |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| idle-scan.sh in hfu-idle-scan.timer | Chemins acceptés, sauf `.cache` et `snap`. | Une infection nouvelle. Une paire déjà dans `scan-skip.seen` ne renvoie pas de courrier. | Pas de bloc de commande. |

| Réglage | Valeur |
| --- | --- |
| minuteur | `OnBootSec=15min`, `OnUnitActiveSec=1h`, `Persistent=true` |
| limites | `Nice` 19, `IOSchedulingClass=idle`, `CPUQuota` 20 % |
| attente | `steam`, `steamwebhelper`, `lutris`, `heroic`, `wineserver`, `gamescope` |
| répertoires sautés | `shadercache`, `downloading` |
| fichiers | exécutables de toute taille, et les autres fichiers de 25 Mo ou moins plus récents que `scan-skip.stamp` |
| tampon | n'avance qu'après une passe propre |
| couverts | `/var/jeux`, `$HOME/.steam`, `$HOME/.local/share/Steam` |
| non couverts | `$HOME/.cache`, `$HOME/snap` |

## debsums

| Service qui surveille      | Zones                                   | Ce qui part en alerte                                                    | Commande du courrier                                                      |
| -------------------------- | --------------------------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------- |
| debsums.sh in boot-scan.sh | Fichiers des paquets, via `debsums -s`. | Fichiers de paquets modifiés qui ne sont pas dans une liste d'exclusion. | `sudo bash /opt/high-fortress-user/bin/debsums-ignore-log.sh '<journal>'` |

La ligne mirrors.dat est retirée seulement lorsque le hash actuel correspond à l'empreinte. Il n'y a pas de fichier d'ignorance globale pour ce chemin.

## auditd

| Service qui surveille | Zones                                          | Ce qui part en alerte                                                       | Commande du courrier |
| --------------------- | ---------------------------------------------- | --------------------------------------------------------------------------- | -------------------- |
| auditd                | /etc/audit/rules.d/00-high-fortress-user.rules | Pas de courrier propre. La passe de démarrage n'envoie pas d'alerte auditd. | Aucune.              |

Une surveillance de clé `account` est ajoutée pour `.ssh/authorized_keys`, `.bashrc`, `.profile`, `.bash_profile`, `.config/autostart` et `.config/systemd/user` lorsque ce chemin existe déjà.

Un chemin absent est sauté, donc `augenrules` charge encore les règles.

## Fail2Ban

| Service qui surveille | Zones                    | Ce qui part en alerte   | Commande du courrier |
| --------------------- | ------------------------ | ----------------------- | -------------------- |
| fail2ban              | /etc/fail2ban/jail.local | Pas de courrier propre. | Aucune.              |

## CrowdSec

| Service qui surveille | Zones          | Ce qui part en alerte   | Commande du courrier |
| --------------------- | -------------- | ----------------------- | -------------------- |
| crowdsec              | /etc/crowdsec/ | Pas de courrier propre. | Aucune.              |

## UFW

| Service qui surveille | Zones                                                                        | Ce qui part en alerte   | Commande du courrier |
| --------------------- | ---------------------------------------------------------------------------- | ----------------------- | -------------------- |
| ufw                   | Entrée refusée, sortie autorisée, routage autorisé, boucle locale autorisée. SSH est limité aux préfixes directement connectés. | Pas de courrier propre. | Aucune.              |

## Lynis

| Service qui surveille              | Zones                     | Ce qui part en alerte                                                                   | Commande du courrier |
| ---------------------------------- | ------------------------- | --------------------------------------------------------------------------------------- | -------------------- |
| verify/workstation.sh and hf lynis | /var/log/lynis-report.dat | Un score sous 80 est un avertissement dans le rapport de vérification, pas un courrier. | Aucune.              |

`verify/workstation.sh` signale Secure Boot avec `mokutil`.

Il signale une racine LUKS lorsque `lsblk` montre `crypt` pour la source de la racine.

L'absence de l'un des deux est un avertissement.

L'installeur laisse les deux inchangés.

## Avis de redémarrage

| Service qui surveille | Zones | Ce qui part en alerte | Commande du courrier |
| --- | --- | --- | --- |
| reboot-notice.sh in hfu-reboot-notice.timer | `/var/run/reboot-required`, `/var/run/reboot-required.pkgs`, et `fwupdmgr get-updates` lorsque cette commande sort avec 0 | Un ensemble nouveau. La même empreinte dans `reboot-notice.seen` ne renvoie pas de courrier. | Pas de bloc de commande. |

La minuterie est `OnBootSec=20min` et `OnUnitActiveSec=6h`, avec `Persistent=true`.

`Nice` vaut 19, `IOSchedulingClass` vaut `idle`, et `CPUQuota` vaut 20 %.

Un `steam`, `steamwebhelper`, `lutris`, `heroic`, `wineserver` ou `gamescope` en cours saute le courrier.

Cette passe laisse `reboot-notice.seen` inchangé.

Le script ne redémarre pas la machine.

La ligne de résumé est `Un redémarrage est utile. La machine n'a pas été redémarrée.`
