# Agents

Durcissement **workstation** Ubuntu 26.04. Inspiré de `palarchsys/high-fortress` (VPS), mais **ne pas** copier les durcissements VPS qui cassent un desktop.

## Interdits (non négociables)

- Ubuntu Pro est **obligatoire** (jeton, sauf déjà attachée). ESM infra/apps + livepatch : échec = stop install.
- Ne jamais changer le mot de passe **root** ni celui de l’utilisateur courant (`chpasswd`, `passwd`, `usermod -p`, `chage` qui force une expiration).
- Ne jamais casser Firefox, Steam, Discord, Telegram, les dépôts APT, KVM, QEMU/libvirt.
- Ne pas `chmod 700` les compilateurs (Proton / DXVK / dev).
- Ne pas `noexec` sur `/tmp` (Electron, Steam, Firefox).
- Ne pas blacklister USB storage.
- Ne pas désactiver IPv6, user namespaces, ptrace_scope>1.
- Ne pas `ufw default deny outgoing`.
- Ne pas `ufw --force reset` si libvirt/docker est actif sans restaurer virbr*/forward.
- Ne pas réécrire `/etc/apt/sources.list` ni les `.sources` existants (ajouter un dépôt Lynis CISOfy est OK).
- Ne pas `aa-enforce` global / remplacer les profils distro.
- Ne pas ClamAV OnAccess sur `/` (I/O Steam / home).
- Ne pas créer d’utilisateur SSH de remplacement, ni `AllowUsers` restrictif.
- Ne pas `PasswordAuthentication no` (session graphique + SSH desktop).
- Ne pas toucher au swap existant (LUKS / hibernation / zram).

## Ordre

Lire `docs/COMPATIBILITY.md`, puis `global.conf`, `lib.sh`, `run.sh`.
