#!/usr/bin/env bash

# Suite 08 — dossier template/ et rendu commun. Le style HTML du poste reste le sien.

hf_section "modèle éditable"
MONO="$(cd -- "${HF_ROOT}/.." && pwd)"
mail_sh="${MONO}/core/mail.sh"
tpl="${HF_ROOT}/template/mail.html"

if grep -q '^MAIL_TEMPLATE="mail.html"$' "${HF_ROOT}/global.conf" \
   && grep -q 'hf_install_mail_templates' "${HF_ROOT}/service/cron/configure.sh" \
   && grep -q 'hf_render_mail' "${HF_ROOT}/service/cron/watchdogs/send.sh" \
   && ! grep -q 'HF_MAIL_REDACT=1' "${HF_ROOT}/service/cron/watchdogs/send.sh" \
   && grep -q 'NOTE_CMD' "${tpl}" \
   && grep -q '<!--NOTE_START-->' "${tpl}" \
   && grep -q '<!--NOTE_END-->' "${tpl}"; then
    hf_pass "mail.wired" "template/mail.html, copie à l'install, rendu sans masquage des identifiants"
else
    hf_fail "mail.wired" "le poste doit rendre template/mail.html via core/mail.sh"
fi

# shellcheck disable=SC1090
source "${mail_sh}"
stage="$(mktemp -d)"
mkdir -p "${stage}/template" "${stage}/dest"
printf '<pre>${CONTENT}</pre>\n' > "${stage}/template/mail.html"
printf '<pre>autre</pre>\n' > "${stage}/template/autre.html"
if DIR_INSTALL_PATH="${stage}" MAIL_TEMPLATE="autre.html" hf_install_mail_templates "${stage}/dest" \
   && [[ -f "${stage}/dest/mail.html" && -f "${stage}/dest/autre.html" ]] \
   && grep -q 'autre' "${stage}/dest/autre.html"; then
    hf_pass "mail.install-many" "tous les .html de template/ sont copiés"
else
    hf_fail "mail.install-many" "la copie des modèles a échoué"
fi
rm -rf "${stage}"

export TITLE="Essai" PROJECT_NAME="High-Fortress User" HOSTNAME="poste" DATE="2026-01-01" MODULE_NAME="Test"
export CONTENT='<script>$HOME'
export NOTE="" NOTE_CMD=""
unset HF_MAIL_REDACT || true
if rendered="$(hf_render_mail "${tpl}")" \
   && printf '%s' "${rendered}" | grep -q '<pre' \
   && printf '%s' "${rendered}" | grep -q '&lt;script&gt;\$HOME' \
   && ! printf '%s' "${rendered}" | grep -q '<!--NOTE_START-->'; then
    hf_pass "mail.render" "échappement HTML et bloc note retiré"
else
    hf_fail "mail.render" "le rendu du modèle poste est invalide"
fi

export NOTE="voir le journal" NOTE_CMD="sudo true"
if rendered="$(hf_render_mail "${tpl}")" \
   && printf '%s' "${rendered}" | grep -q 'voir le journal' \
   && printf '%s' "${rendered}" | grep -q 'sudo true'; then
    hf_pass "mail.note" "NOTE et NOTE_CMD sont insérés"
else
    hf_fail "mail.note" "le second bloc du modèle n'est pas rendu"
fi
