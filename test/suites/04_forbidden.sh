#!/usr/bin/env bash

# Suite 04 — le poste n'exécute pas le durcissement serveur.

hf_section "interdits poste"
MONO="$(cd -- "${HF_ROOT}/.." && pwd)"

active_hits() {
    local pattern="$1"
    grep -RInE --include='*.sh' --include='*.conf' --include='*.service' "${pattern}" "${HF_ROOT}" \
        | grep -vE ':[0-9]+:[[:space:]]*#' || true
}
forbid() {
    local id="$1"
    local pattern="$2"
    local hits
    hits="$(active_hits "${pattern}")"
    if [[ -n "${hits}" ]]; then
        hf_fail "${id}" "$(printf '%s' "${hits}" | tr '\n' ' ' | head -c 500)"
    else
        hf_pass "${id}" "aucune ligne active"
    fi
}
forbid "forbid.password-no" '^[[:space:]]*PasswordAuthentication[[:space:]]+no([[:space:]]|$)'
forbid "forbid.allowusers" '^[[:space:]]*AllowUsers[[:space:]]'
forbid "forbid.ufw-out" 'ufw[[:space:]]+default[[:space:]]+deny[[:space:]]+outgoing'
forbid "forbid.ufw-reset" 'ufw[[:space:]]+--force[[:space:]]+reset'
forbid "forbid.ipv6" 'disable_ipv6[[:space:]]*='
forbid "forbid.usb" '(^|[[:space:]])(blacklist|install)[[:space:]]+usb-storage'
tmp_hits="$(active_hits '/tmp[^#]*noexec|noexec[^#]*/tmp' | grep -v '/verify/' | grep -v 'est noexec' || true)"
if [[ -n "${tmp_hits}" ]]; then
    hf_fail "forbid.tmp-noexec" "$(printf '%s' "${tmp_hits}" | tr '\n' ' ' | head -c 500)"
else
    hf_pass "forbid.tmp-noexec" "aucune ligne active"
fi

chpasswd_hits="$(grep -RIn --include='*.sh' --exclude-dir=test 'chpasswd' "${HF_ROOT}" \
    | grep -vE ':[0-9]+:[[:space:]]*#' \
    | grep -v '\*chpasswd\*' \
    | grep -v 'aucun chpasswd' \
    | grep -v 'jamais chpasswd' || true)"
if [[ -n "${chpasswd_hits}" ]]; then
    hf_fail "forbid.chpasswd" "$(printf '%s' "${chpasswd_hits}" | tr '\n' ' ' | head -c 500)"
else
    hf_pass "forbid.chpasswd" "pas d'appel chpasswd"
fi

if grep -RInE --include='*.sh' 'chmod[[:space:]]+700[[:space:]]+.*(gcc|g\+\+|/usr/bin/cc)' "${HF_ROOT}" | grep -vE ':[0-9]+:[[:space:]]*#' | grep -q .; then
    hf_fail "forbid.compiler-700" "chmod 700 sur un compilateur"
else
    hf_pass "forbid.compiler-700" "compilateurs non verrouillés"
fi

if [[ -f "${MONO}/server/service/ssh/00-high-fortress-user.conf" ]]; then
    hf_fail "forbid.dropin-on-server" "le drop-in poste est dans server/service/ssh"
else
    hf_pass "forbid.dropin-on-server" "drop-in poste absent du serveur"
fi
if grep -q '^PasswordAuthentication yes$' "${MONO}/server/service/ssh/sshd_config.conf" 2>/dev/null; then
    hf_fail "forbid.server-ssh-password" "le sshd serveur accepte le mot de passe"
else
    hf_pass "forbid.server-ssh-password" "sshd serveur sans mot de passe"
fi
