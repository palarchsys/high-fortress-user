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

Exclus : `$HOME/.steam`, `$HOME/.local/share/Steam`, l'utilisateur `clamav`, root (`OnAccessExcludeRootUID yes`), et les fichiers au-dessus de 25M. `.clamav-quarantine-lock.*` est un verrou de déplacement, pas un logiciel malveillant, donc `clamav-event.sh` sort en 0 avant `log_alert`.

## Analyse ClamAV au démarrage

| Service qui surveille     | Zones             | Ce qui part en alerte                                 | Commande du courrier     |
| ------------------------- | ----------------- | ----------------------------------------------------- | ------------------------ |
| clamav.sh in boot-scan.sh | /home, /opt, /tmp | Des infections. Une analyse propre reste silencieuse. | Pas de bloc de commande. |

L'analyse élague les répertoires de l'accès et les noms `BraveSoftware`, `.config/discord`, `.thunderbird`, `thunderbird`, `libvirt` et `snap-private-tmp`, afin de ne pas analyser ces arbres deux fois.

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
