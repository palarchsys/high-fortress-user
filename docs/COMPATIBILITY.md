# Compatibilité workstation

High-Fortress User durcit un **Ubuntu 26.04 desktop** sans le transformer en VPS.

Inspiré de [`palarchsys/high-fortress`](https://github.com/palarchsys/high-fortress) : mêmes briques (sysctl, SSH, UFW, Fail2Ban, AppArmor, AIDE, auditd, rkhunter, chkrootkit, ClamAV, debsums, Lynis) — **pas** les durcissements qui cassent un poste.

## Jamais

| Action VPS (high-fortress) | Pourquoi c’est refusé ici |
|----------------------------|---------------------------|
| `chpasswd` root / user | Contrat explicite |
| `chage -M 90` sur les comptes existants | Forcerait un changement de mot de passe |
| Compilateurs `chmod 700` | Steam Proton, DXVK, gcc utilisateur |
| `noexec` sur `/tmp` | Firefox, Discord, Telegram, Electron, Steam |
| Blacklist `usb-storage` | Périphériques USB du desktop |
| `net.ipv6.conf.all.disable_ipv6=1` | Dual-stack, Steam, Discord |
| `ufw default deny outgoing` | APT, Firefox, Steam, Discord, Telegram |
| `ip_forward=0` si libvirt/docker | NAT KVM/QEMU |
| `kernel.unprivileged_userns_clone=0` | Sandbox Firefox / Chromium / Electron |
| `kernel.yama.ptrace_scope≥2` | gdb, certains jeux, tracing |
| `PasswordAuthentication no` + `AllowUsers` | Session graphique + SSH desktop |
| Réécriture `sources.list` | Dépôts Steam / PPA / Ubuntu |
| Purge CUPS / bluetooth / avahi | Impression, BT, mDNS |
| Swap recréé chiffré | LUKS existant, hibernation, zram |
| ClamAV OnAccess sur `/` | I/O disque (jeux, home) |
| `aa-enforce` global | Profils distro Firefox / snaps |
| `cron.allow` limité à un user service | Crontab de l’utilisateur |
| Changement de hostname / `/etc/hosts` | Réseau local, libvirt |

## Préservé

- **Ubuntu Pro** — attach + ESM + livepatch **obligatoires** (Lynis PKGS / livepatch).
- **Firefox** (deb, snap ou flatpak) — user namespaces, `/tmp` exécutable, AppArmor distro.
- **Steam** — outgoing libre, Proton/compilateurs, ptrace_scope=1, pas de scan OnAccess du library.
- **Discord / Telegram** — Electron, `/tmp`, 443/UDP sortant.
- **APT** — sources existantes intactes ; on **ajoute** uniquement CISOfy Lynis.
- **KVM / QEMU / libvirt** — `/dev/kvm`, modules virtio/kvm/vhost/tun, `virbr0`, forward policy ACCEPT si libvirt est installé.

## Lynis

Objectif : **index ≥ 80** (seuil `LYNIS_MIN_SCORE`). Les tests volontairement non appliqués sont documentés dans `/etc/lynis/custom.prf`.
