# Agents

Monodépôt : la carte est `../AGENTS.md`. Ce fichier reste la loi de `user/`.

Durcissement d'un poste Ubuntu 26.04. Le flux est `configure.sh`, puis `config-check.sh`, puis `run.sh`. `install.sh` télécharge l'archive publique et ne lance `run.sh` que si le contrôle réussit.

## Interdits

- Ubuntu Pro est obligatoire (jeton dans `secrets.conf`). ESM infra, ESM apps et Livepatch : un échec arrête l'installation.
- Ne pas modifier les comptes humains créés par l'installateur Ubuntu : pas de `chpasswd`, `passwd`, `usermod` manuel, expiration `chage`, ni changement de home ou de shell.
- Les snaps Firefox et Thunderbird sont retirés. snapd reste. Brave, Thunderbird (dépôt Mozilla), Steam, Discord et KeePassXC restent utilisables. Les dépôts APT déjà présents restent. L'installateur n'installe ni QEMU, ni libvirt, ni Telegram. S'ils sont déjà sur le poste, il ne les retire pas.
- Ne pas `chmod 700` les compilateurs.
- Ne pas monter `/tmp` en `noexec`.
- Ne pas blacklister `usb-storage`.
- Ne pas désactiver IPv6, les user namespaces, ni monter `ptrace_scope` au-dessus de 1.
- Ne pas `ufw default deny outgoing`.
- Ne pas `ufw --force reset`.
- Ne pas réécrire `/etc/apt/sources.list` ni les fichiers `.sources` déjà présents. Ajouter les dépôts Lynis, Brave et Thunderbird (Mozilla) est prévu.
- Ne pas `aa-enforce` global, ne pas installer `apparmor-profiles-extra`, ne pas écrire `apparmor_restrict_unprivileged_userns=0`.
- Ne pas activer ClamAV OnAccess sur `/`.
- Ne pas créer de compte SSH de remplacement, ni poser `AllowUsers`.
- Ne pas passer `PasswordAuthentication` à `no`.
- Ne pas modifier le swap.

## Ordre de lecture

`configure.sh`, `config-check.sh`, `global.conf`, `run.sh`, `lib.sh`.
