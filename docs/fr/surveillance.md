[README complet](README.md)

# Surveillance

Une ligne de journal dans un courrier d'alerte reste sur une seule ligne.

Le courrier d'alerte fait de 400px à 800px de large et suit le volet de lecture entre ces deux largeurs.

Le courrier d'alerte occupe au moins la hauteur du volet de lecture.

## AIDE

| Service qui surveille   | Zones                                               | Ce qui part en alerte                                                 | Commande du courrier                                       |
| ----------------------- | --------------------------------------------------- | --------------------------------------------------------------------- | ---------------------------------------------------------- |
| aide.sh in boot-scan.sh | /etc/aide/aide.conf, database /var/lib/aide/aide.db | Des changements, ou un code non nul qui n'est pas un résultat propre. | `sudo bash /opt/high-fortress-user/bin/aide-refresh-db.sh` |

Les chemins volatils, les journaux, les caches et les répertoires de rapports cron sont exclus dans `config/aide/aide.conf` afin que la base ne soit pas réécrite par ces fichiers.

Les fichiers `*.stamp`, `integrity.sha256` et `rkhunter-mirrors.sha256` du répertoire cron du produit sont exclus.

Le fichier `/etc/crowdsec/hub/.index.json` est exclu.

C'est le catalogue téléchargé par `cscli hub update`.

Les autres fichiers sous `/etc/crowdsec/` sont surveillés.

Le bloc du compte est ajouté après `!/home/`.

La dernière règle qui correspond l'emporte.

Les chemins surveillés sont `.ssh/authorized_keys`, `.bashrc`, `.profile`, `.bash_profile`, `.config/autostart` et `.config/systemd/user` du compte du poste.

`.ssh/known_hosts` et `.ssh/known_hosts.old` sont exclus.

## rkhunter

| Service qui surveille       | Zones                                            | Ce qui part en alerte                                                                      | Commande du courrier     |
| --------------------------- | ------------------------------------------------ | ------------------------------------------------------------------------------------------ | ------------------------ |
| rkhunter.sh in boot-scan.sh | Périmètre du paquet, plus la base de propriétés. | Avertissements, une mise à jour en échec, ou `mirrors.dat modifié hors rkhunter --update`. | `sudo bash /opt/high-fortress-user/bin/rkhunter-refresh-db.sh` |

La commande de recalcul est jointe aux avertissements lorsqu'aucun fichier avéré n'a été déplacé. La ligne d'empreinte et un échec de mise à jour ne l'ajoutent pas.

`/var/lib/rkhunter/db/mirrors.dat` n'est pas ignoré en tant que fichier. L'empreinte `/opt/high-fortress-user/cron/rkhunter-mirrors.sha256` est écrite seulement après un `rkhunter --update` qui retourne 0 ou 2. Un hash différent est une alerte. Le contrôle a lieu avant le `--update` suivant.

Les fichiers de `/dev/shm` et la socket `/dev/log` sont autorisés.

Ils ne produisent pas l'avertissement `Suspicious file types found in /dev`.

Une ligne restante qui contient `INFECTED`, ou `Rootkit` et un chemin absolu de fichier régulier, est une détection avérée.

Une ligne qui contient `Rootkit Hunter` est ignorée, sauf si elle contient aussi `INFECTED`.

Ce fichier va dans `/var/lib/clamav/quarantine`.

Un détenteur qui n'est pas protégé reçoit `TERM`.

Les détenteurs protégés sont le pid 1, l'uid 0, un nom vide, `systemd`, `sshd`, `unbound`, `fail2ban` et `gamescope`.

La même règle couvre `/etc/passwd`, `/etc/shadow`, `/etc/sudoers`, `/etc/ssh/sshd_config`, `/etc/ufw/ufw.conf`, `/usr/bin/sudo`, `/usr/bin/passwd` et `/usr/sbin/sshd`.

Un chemin ou un détenteur protégé reste en place.

Le courrier dit `non mis en quarantaine`.

Chaque fichier déplacé ajoute une commande de restauration.

```bash
sudo bash /opt/high-fortress-user/bin/quarantine-restore.sh <id>
```

Le registre est `/opt/high-fortress-user/cron/quarantine.registry`.

La ligne de succès est `fichier remis en place`.

Un avertissement qui n'est pas avéré reste un courrier.

## chkrootkit

| Service qui surveille         | Zones                   | Ce qui part en alerte                               | Commande du courrier                                                         |
| ----------------------------- | ----------------------- | --------------------------------------------------- | ---------------------------------------------------------------------------- |
| chkrootkit.sh in boot-scan.sh | /usr/sbin/chkrootkit -q | Toute sortie restante après les listes d'exclusion. | `sudo bash /opt/high-fortress-user/bin/chkrootkit-ignore-log.sh '<journal>'` |

Les lignes connues sont dans `src/config/chkrootkit/patterns.ignore` et dans `cron/chkrootkit.local.ignore`.

Le fichier local est rempli seulement par la commande du courrier, et seulement pour des lignes que vous reconnaissez.

Une détection avérée utilise le même déplacement et la même règle `TERM` que rkhunter.

La commande d'enregistrement est jointe seulement lorsqu'aucun fichier avéré n'a été déplacé.

## ClamAV à l'accès

| Service qui surveille           | Zones                      | Ce qui part en alerte                            | Commande du courrier               |
| ------------------------------- | -------------------------- | ------------------------------------------------ | ---------------------------------- |
| clamonacc, then clamav-event.sh | Dossiers XDG, /tmp, /var/tmp, /opt. | Une vraie détection. Les verrous n'alertent pas. | `sudo bash /opt/high-fortress-user/bin/quarantine-restore.sh <id>` |

| Exclusion | Règle |
| --- | --- |
| `scan-skip.paths` | Chemins acceptés seulement. |
| utilisateur `clamav` | `OnAccessExcludeUname clamav` |
| root | `OnAccessExcludeRootUID yes` |
| taille | Fichiers au-dessus de 25 Mo. |
| /var/lib/snapd, /snap | Exclusion fixe. |
| /var/lib/clamav/quarantine, /var/lib/clamav/tmp | Exclusion fixe. |
| /opt/high-fortress-user, /var/log | Exclusion fixe. |

Le fichier livré liste :

- `$HOME/.cache`
- `$HOME/snap`
- `/var/jeux`

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

`clamav-event.sh` sort en 0 avant `hf_log_alert`.

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
| clamav.sh in boot-scan.sh | /home, /opt, /tmp | Des infections. Une analyse propre reste silencieuse. | `sudo bash /opt/high-fortress-user/bin/quarantine-restore.sh <id>` |

L'analyse élague les entrées `OnAccessExcludePath` et les chemins acceptés de `scan-skip.paths`.

Elle élague aussi `proc`, `sys`, `dev`, `var/lib/docker`, `var/lib/libvirt`, `libvirt` et `snap-private-tmp`.

Les fichiers de plus de 25 Mo sont laissés de côté.

La liste des fichiers est écrite sous `/run/high-fortress-user`.

Lorsque `/run/clamav/clamd.ctl` existe, la passe pose `HF_CLAM_MODE=daemon`.

Sinon elle utilise `clamscan`.

L'unité plafonne cette passe à 50 % de la machine.

Le nombre est écrit lors de la configuration cron.

Un changement ultérieur du nombre de CPU demande de relancer cette configuration.

`hfu-boot-chain.service` lance cette passe, puis l'analyse différée, puis l'avis de redémarrage.

La chaîne part lorsque `multi-user.target` est atteint.

L'échec d'une passe ne bloque pas la suivante.

Un fichier illisible, sans ligne `FOUND`, n'envoie pas de courrier.

Un processus `clamscan` arrêté par un signal envoie un courrier.

Le courrier nomme le signal et chaque fichier non lu.

Les autres fichiers de la passe sont analysés.

Deux plantages de suite arrêtent la passe ClamAV.

Le courrier dit alors que les fichiers restants n'ont pas été lus.

## Analyse ClamAV périodique

| Service qui surveille | Zones | Ce qui part en alerte | Commande du courrier |
| --- | --- | --- | --- |
| clamav.sh dans hfu-periodic-scan.timer | /home, /opt, /tmp, avec les mêmes élagages que la passe de démarrage. | Des infections. Une passe propre reste silencieuse. | `sudo bash /opt/high-fortress-user/bin/quarantine-restore.sh <id>` |

Le minuteur est `OnBootSec=2h` et `OnUnitActiveSec=2h`, avec `Persistent=false`.

`Nice` vaut 19, `IOSchedulingClass` vaut `idle`, et `CPUQuota` est le même quota que la passe de démarrage.

Un `lutris`, `heroic` ou `gamescope` en cours saute la passe.

`/run/high-fortress-user/clamav.lock` empêche une seconde passe de démarrer.

## Passe horaire

| Service qui surveille | Zones | Ce qui part en alerte | Commande du courrier |
| --- | --- | --- | --- |
| hourly-scan.sh dans hfu-hourly-scan.timer | AIDE, puis rkhunter, puis chkrootkit, puis debsums. Mêmes contrôles que la passe de démarrage. | Les mêmes trouvailles que chacun de ces contrôles de démarrage. Une passe propre reste silencieuse. | La commande du courrier de ce contrôle. |

Le minuteur est `OnBootSec=1h` et `OnUnitActiveSec=1h`, avec `Persistent=false`.

`Nice` vaut 19, `IOSchedulingClass` vaut `idle`, et `CPUQuota` est le même quota que la passe de démarrage.

La passe de démarrage lance ces quatre contrôles.

## Analyse ClamAV différée

| Service qui surveille                | Zones                                                                                                | Ce qui part en alerte                                                                                                      | Commande du courrier     |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| idle-scan.sh in hfu-idle-scan.timer | Chemins acceptés, sauf `.cache` et `snap`. | Une infection nouvelle. Une paire déjà dans `scan-skip.seen` ne renvoie pas de courrier. | `sudo bash /opt/high-fortress-user/bin/quarantine-restore.sh <id>` |

| Réglage | Valeur |
| --- | --- |
| minuteur | `OnUnitActiveSec=1h`, `Persistent=false` |
| limites | `Nice` 19, `IOSchedulingClass=idle`, `CPUQuota` 50 % de la machine |
| attente | `lutris`, `heroic`, `gamescope` |
| répertoires sautés | `shadercache`, `downloading` |
| fichiers | exécutables de toute taille, et les autres fichiers de 25 Mo ou moins plus récents que `scan-skip.stamp` |
| tampon | n'avance qu'après une passe propre |
| couverts | `/var/jeux` |
| non couverts | `$HOME/.cache`, `$HOME/snap` |

Une infection nouvelle appelle `clamav-response.sh`.

Le fichier est déplacé dans `/var/lib/clamav/quarantine`. Un détenteur reçoit TERM. Le pid 1, l'uid 0, un nom vide, et les noms systemd, sshd, unbound, fail2ban et gamescope restent. Les nouveaux flux sortants sont isolés pendant 120 secondes.

Une paire signature et chemin déjà connue n'appelle pas cette réponse.

Un processus `clamscan` arrêté par un signal envoie un courrier.

Le courrier nomme le signal et chaque fichier non lu.

Les autres fichiers de la passe sont analysés.

Deux plantages de suite arrêtent la passe ClamAV.

Le courrier dit alors que les fichiers restants n'ont pas été lus.

Le tampon reste en place.

## debsums

| Service qui surveille      | Zones                                   | Ce qui part en alerte                                                    | Commande du courrier                                                      |
| -------------------------- | --------------------------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------- |
| debsums.sh in boot-scan.sh | Fichiers des paquets, via `debsums -s`. | Chaque paquet encore signalé est réinstallé. Le courrier nomme la correction. | Pas de bloc de commande. |

La ligne mirrors.dat est retirée seulement lorsque le hash actuel correspond à l'empreinte. Il n'y a pas de fichier d'ignorance globale pour ce chemin.

Une ligne modifiée sous `/usr/lib/*/perl-base/unicore/` du paquet `perl-base` est retirée avant cette réinstallation.

## auditd

| Service qui surveille | Zones                                          | Ce qui part en alerte                                                       | Commande du courrier |
| --------------------- | ---------------------------------------------- | --------------------------------------------------------------------------- | -------------------- |
| auditd                | /etc/audit/rules.d/00-high-fortress-user.rules | Pas de courrier propre. behavior.sh dans la passe de démarrage envoie le courrier d'un exec-tmp. | Aucune.              |

Une surveillance de clé `account` est ajoutée pour `.ssh/authorized_keys`, `.bashrc`, `.profile`, `.bash_profile`, `.config/autostart` et `.config/systemd/user` lorsque ce chemin existe déjà.

Un chemin absent est sauté, donc `augenrules` charge encore les règles.

`tail.rules` enregistre l'attache ptrace, le chargement et le retrait de module, et `execve` sous `/tmp`, `/var/tmp` et `/dev/shm`.

## Fail2Ban

| Service qui surveille | Zones                    | Ce qui part en alerte   | Commande du courrier |
| --------------------- | ------------------------ | ----------------------- | -------------------- |
| fail2ban              | /etc/fail2ban/jail.local | Pas de courrier propre. | Aucune.              |

## CrowdSec

| Service qui surveille | Zones          | Ce qui part en alerte   | Commande du courrier |
| --------------------- | -------------- | ----------------------- | -------------------- |
| crowdsec              | /etc/crowdsec/ | Pas de courrier propre. | Aucune.              |

La durée de blocage est `HFU_CROWDSEC_BAN_DURATION`, par défaut `48h`.

Un nom de `config/crowdsec/optional.list` n'est installé que si le hub l'accepte.

## UFW

| Service qui surveille | Zones                                                                        | Ce qui part en alerte   | Commande du courrier |
| --------------------- | ---------------------------------------------------------------------------- | ----------------------- | -------------------- |
| ufw                   | Entrée refusée, sortie autorisée, routage autorisé, boucle locale autorisée. SSH est limité aux préfixes directement connectés. | Pas de courrier propre. | Aucune.              |

## Intégrité

| Service qui surveille | Zones | Ce qui part en alerte | Commande du courrier |
| --- | --- | --- | --- |
| integrity.sh dans boot-scan.sh | `config/integrity/paths.list` | Un changement d'empreinte. La première passe écrit le cachet et reste silencieuse. | Pas de bloc de commande. |

La passe suit aide.sh.

Le cachet est `/opt/high-fortress-user/cron/integrity.sha256`.

## Comportement

| Service qui surveille | Zones | Ce qui part en alerte | Commande du courrier |
| --- | --- | --- | --- |
| behavior.sh dans boot-scan.sh | `execve` sous `/tmp`, `/var/tmp` et `/dev/shm`. | Un événement depuis le cachet précédent. La première passe écrit le cachet et reste silencieuse. | Pas de bloc de commande. |

La passe suit rkhunter.sh.

auditd reste en service.

Le cachet est `/opt/high-fortress-user/cron/behavior.stamp`.

## Journal sortant

| Service qui surveille | Zones | Ce qui part en alerte | Commande du courrier |
| --- | --- | --- | --- |
| table nftables `inet hfu_egress`, puis egress-watch.sh dans boot-scan.sh | Flux sortants nouveaux hors des ports 53, 80 et 443. | Une ligne noyau préfixée `hfu-egress` depuis le cachet précédent. La première passe écrit le cachet et reste silencieuse. | Pas de bloc de commande. |

La table est installée avec la politique accept.

La passe suit debsums.sh.

Le cachet est `/opt/high-fortress-user/cron/egress.stamp`.

Ce contrôle n'isole pas le réseau.

La ligne noyau est suivie du processus, du pid et de l'uid.

La clé audit est `hfu-egress`.

La politique de la table reste accept.

Le sortant reste allow.

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

La minuterie est `OnUnitActiveSec=6h`, avec `Persistent=false`.

La chaîne de démarrage lance cet avis après l'analyse différée.

`Nice` vaut 19, `IOSchedulingClass` vaut `idle`, et `CPUQuota` vaut 50 % de la machine.

Un `lutris`, `heroic` ou `gamescope` en cours saute le courrier.

Cette passe laisse `reboot-notice.seen` inchangé.

Le script ne redémarre pas la machine.

La ligne de résumé est `Un redémarrage est utile. La machine n'a pas été redémarrée.`
