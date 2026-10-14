[README complet](README.md)

# Surveillance

## AIDE

| Service qui surveille   | Zones                                               | Ce qui part en alerte                                                 | Commande du courrier                                       |
| ----------------------- | --------------------------------------------------- | --------------------------------------------------------------------- | ---------------------------------------------------------- |
| aide.sh in boot-scan.sh | /etc/aide/aide.conf, database /var/lib/aide/aide.db | Des changements, ou un code non nul qui n'est pas un résultat propre. | `sudo bash /opt/high-fortress-user/bin/aide-refresh-db.sh` |

Les chemins volatils, les journaux, les caches et les répertoires de rapports cron sont exclus dans `service/aide/aide.conf` afin que la base ne soit pas réécrite par ces fichiers.

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

Exclus du scan à l'accès : chaque chemin accepté de `/opt/high-fortress-user/cron/scan-skip.paths`, l'utilisateur `clamav`, root (`OnAccessExcludeRootUID yes`), et les fichiers au-dessus de 25 Mo. Le fichier livré à l'installation liste `$HOME/.steam`, `$HOME/.local/share/Steam`, `$HOME/.cache`, `$HOME/snap` et `/var/jeux`. Brave, Thunderbird et Discord n'y figurent pas. Une ligne relative, vide, ou exactement `/`, `/home`, `/opt`, `/tmp`, `/etc`, `/usr`, `/var`, `/boot`, `/root`, `/home/<user>`, Téléchargements ou Bureau est ignorée et ajoutée à `/opt/high-fortress-user/cron/security_logs/scan-skip.log`. `/var/jeux` est un répertoire vide, mode 750, propriétaire l'utilisateur du poste. Ce n'est pas un compte séparé. `.clamav-quarantine-lock.*` est un verrou de déplacement, pas un logiciel malveillant, donc `clamav-event.sh` sort en 0 avant `log_alert`.

La liste se modifie avec `scan-skip.sh`. La même réécriture tourne au début de `boot-scan.sh`. Un `scan-skip.paths` déjà présent n'est pas remplacé lorsque l'installeur tourne de nouveau.

```bash
sudo bash /opt/high-fortress-user/bin/scan-skip.sh list
sudo bash /opt/high-fortress-user/bin/scan-skip.sh add /var/jeux/steam
sudo bash /opt/high-fortress-user/bin/scan-skip.sh del /var/jeux/steam
```

`list` affiche un chemin accepté par ligne. `add` affiche `Chemin ajouté : <path>`. Un chemin déjà présent affiche `Ce chemin est déjà exclu : <path>`. `del` affiche `Chemin retiré : <path>`. Un chemin refusé affiche `Chemin refusé : <path>`. La commande réécrit les lignes `OnAccessExcludePath` entre `# BEGIN High-Fortress User scan-skip` et `# END High-Fortress User scan-skip` dans `/etc/clamav/clamd.conf`. `clamav-daemon` n'est rechargé que lorsque ce bloc change. Un chemin caché reçoit une ligne `ALLOWHIDDENDIR` dans `/etc/rkhunter.conf.local` lorsqu'elle manque. Les lignes rkhunter déjà présentes restent.

## Analyse ClamAV au démarrage

| Service qui surveille     | Zones             | Ce qui part en alerte                                 | Commande du courrier     |
| ------------------------- | ----------------- | ----------------------------------------------------- | ------------------------ |
| clamav.sh in boot-scan.sh | /home, /opt, /tmp | Des infections. Une analyse propre reste silencieuse. | Pas de bloc de commande. |

L'analyse élague les répertoires de l'accès et les chemins acceptés de `scan-skip.paths`. Elle élague aussi `proc`, `sys`, `dev`, `var/lib/docker`, `var/lib/libvirt`, `libvirt` et `snap-private-tmp`. Elle lit les fichiers avec `clamscan`, dans l'unité de démarrage. Elle n'appelle pas `clamdscan`. Brave, Thunderbird et Discord restent dans cette passe.

## Analyse ClamAV différée

| Service qui surveille                | Zones                                                                                                | Ce qui part en alerte                                                                                                      | Commande du courrier     |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| idle-scan.sh in hfu-idle-scan.timer  | Chemins acceptés de `scan-skip.paths`, sauf un répertoire dont le dernier composant est `.cache` ou `snap`. | Une infection nouvelle. Une signature et un chemin déjà enregistrés dans `/opt/high-fortress-user/cron/scan-skip.seen` ne renvoient pas de courrier. | Pas de bloc de commande. |

`hfu-idle-scan.timer` utilise `OnBootSec=15min`, `OnUnitActiveSec=1h` et `Persistent=true`. `Nice` vaut `WATCHDOG_LIMIT_NICE` (19), `IOSchedulingClass=idle`, et `CPUQuota` vaut `WATCHDOG_CPU_LIMIT` (20 %). La passe sort en 0 sans analyser tant que `steam`, `steamwebhelper`, `lutris`, `heroic`, `wineserver` ou `gamescope` tourne. Elle saute les répertoires `shadercache` et `downloading`. Elle analyse les fichiers exécutables quelle que soit leur taille, et les autres fichiers de 25 Mo ou moins plus récents que `/opt/high-fortress-user/cron/scan-skip.stamp`. Le tampon n'avance qu'après une passe propre. `/var/jeux`, `$HOME/.steam` et `$HOME/.local/share/Steam` sont couverts. `$HOME/.cache` et `$HOME/snap` ne le sont pas.

## debsums

| Service qui surveille      | Zones                                   | Ce qui part en alerte                                                    | Commande du courrier                                                      |
| -------------------------- | --------------------------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------- |
| debsums.sh in boot-scan.sh | Fichiers des paquets, via `debsums -s`. | Fichiers de paquets modifiés qui ne sont pas dans une liste d'exclusion. | `sudo bash /opt/high-fortress-user/bin/debsums-ignore-log.sh '<journal>'` |

La ligne mirrors.dat est retirée seulement lorsque le hash actuel correspond à l'empreinte. Il n'y a pas de fichier d'ignorance globale pour ce chemin.

## auditd

| Service qui surveille | Zones                                          | Ce qui part en alerte                                                       | Commande du courrier |
| --------------------- | ---------------------------------------------- | --------------------------------------------------------------------------- | -------------------- |
| auditd                | /etc/audit/rules.d/00-high-fortress-user.rules | Pas de courrier propre. La passe de démarrage n'envoie pas d'alerte auditd. | Aucune.              |

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
| ufw                   | Entrée refusée, sortie autorisée, routage autorisé, boucle locale autorisée. | Pas de courrier propre. | Aucune.              |

## Lynis

| Service qui surveille              | Zones                     | Ce qui part en alerte                                                                   | Commande du courrier |
| ---------------------------------- | ------------------------- | --------------------------------------------------------------------------------------- | -------------------- |
| verify/workstation.sh and hf lynis | /var/log/lynis-report.dat | Un score sous 80 est un avertissement dans le rapport de vérification, pas un courrier. | Aucune.              |
