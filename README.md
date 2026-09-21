# High-Fortress User

Durcissement d’un **poste Ubuntu 26.04** (workstation), pas d’un VPS.

Inspiré de [high-fortress](https://github.com/palarchsys/high-fortress) (SSH, UFW, Fail2Ban, AppArmor, AIDE, auditd, rkhunter, chkrootkit, ClamAV, sysctl, Lynis) — **sans** les durcissements qui cassent un desktop.

Dépôt : [https://github.com/palarchsys/high-fortress-user](https://github.com/palarchsys/high-fortress-user) (privé)

## Contrat

- **Ne change jamais** le mot de passe root ni celui de l’utilisateur courant.
- **Ne casse pas** Firefox, Steam, Discord, Telegram, les dépôts APT, KVM, QEMU/libvirt.
- **Ubuntu Pro obligatoire** (attache + ESM infra/apps + livepatch).
- Vise un **bon score Lynis** (seuil 80, tests VPS documentés et sautés).

Détail : [`docs/COMPATIBILITY.md`](docs/COMPATIBILITY.md).

## Installation

Le dépôt est **privé**. La méthode principale est un clone, pas `curl | bash` anonyme.

```bash
git clone git@github.com:palarchsys/high-fortress-user.git
cd high-fortress-user
sudo bash run.sh
```

Avec un jeton GitHub :

```bash
curl -fsSL -H "Authorization: Bearer $GH_TOKEN" \
  https://raw.githubusercontent.com/palarchsys/high-fortress-user/main/install.sh \
  | sudo bash
```

Pendant l’install :

- **jeton Ubuntu Pro** (obligatoire, sauf machine déjà attachée) — [ubuntu.com/pro/dashboard](https://ubuntu.com/pro/dashboard)
- e-mail d’alertes watchdogs (Entrée = journaux locaux seulement, **pas de Postfix**)

## Ce qui est appliqué

| Brique | Comportement desktop |
|--------|----------------------|
| Sysctl | Martians, redirects, kptr, dumps, BPF JIT — **pas** IPv6 off, **pas** userns off, ptrace=1 |
| SSH | Drop-in `sshd_config.d/` : `PermitRootLogin no`, banner, MaxAuthTries — **PasswordAuthentication conservé**, port existant |
| UFW | Deny incoming, **allow outgoing**, limit SSH, `virbr*` si libvirt |
| Fail2Ban | Jail `sshd` (port détecté), action UFW |
| AppArmor | Service enabled, **pas** d’aa-enforce global |
| AIDE | Base SHA512, home / snap / steam / libvirt exclus |
| auditd | Règles ciblées `/etc`, SSH, sudoers, libvirt |
| rkhunter / chkrootkit / debsums | Install + baseline + cron |
| ClamAV | Daemon + freshclam + scan hebdo — **pas** OnAccess `/` |
| Unattended-upgrades | Mises à jour de **sécurité** uniquement |
| PAM | YESCRYPT, pwquality (futurs mots de passe), faillock — **aucun `chpasswd`** |
| Ubuntu Pro | **Obligatoire** : attach + `esm-infra` + `esm-apps` + livepatch |
| Lynis | Dépôt CISOfy + `custom.prf` des exceptions desktop |

## Après l’install

```bash
sudo bash verify/workstation.sh
sudo bash lynis.sh
```

Journaux : `/var/log/high-fortress-user/`.

Un reboot peut être recommandé (noyau / libc) ; les mots de passe et sessions graphiques restent les vôtres.
