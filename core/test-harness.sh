#!/usr/bin/env bash
# =============================================================================
# File       : core/test-harness.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

hft_get_timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

hft_log() {
    local line="[$(hft_get_timestamp)] $*"
    printf '%s\n' "$line"
    if [[ -n "${HF_RUN_LOG:-}" ]]; then
        printf '%s\n' "$line" >> "${HF_RUN_LOG}"
    fi
    if [[ -n "${HFT_SUITE_LOG:-}" ]]; then
        printf '%s\n' "$line" >> "${HFT_SUITE_LOG}"
    fi
}

hft_record() {
    local status="$1"
    local id="$2"
    local msg="$3"
    printf '%s\t%s\t%s\n' "$status" "$id" "$msg" >> "${HFT_RESULT_TSV}"
}

hft_pass() {
    HFT_PASS=$((HFT_PASS + 1))
    hft_log "PASS  $1 — $2"
    hft_record PASS "$1" "$2"
}

hft_fail() {
    HFT_FAIL=$((HFT_FAIL + 1))
    hft_log "FAIL  $1 — $2"
    hft_record FAIL "$1" "$2"
}

hft_warn() {
    HFT_WARN=$((HFT_WARN + 1))
    hft_log "WARN  $1 — $2"
    hft_record WARN "$1" "$2"
}

hft_skip() {
    HFT_SKIP=$((HFT_SKIP + 1))
    hft_log "SKIP  $1 — $2"
    hft_record SKIP "$1" "$2"
}

hft_section() {
    hft_log ""
    hft_log "── $1 ──"
}

hft_check_command() { command -v "$1" >/dev/null 2>&1; }

hft_load_project_config() {
    # shellcheck disable=SC1091
    set +u
    source "${HFT_ROOT}/config/global.conf"
    set -u
}

hft_check_envsubst_leftover() {
    local file="$1"
    grep -oE '\$\{[A-Z_][A-Z0-9_]*\}' "$file" 2>/dev/null | sort -u || true
}

hft_begin() {
    local stamp
    stamp="$(date '+%Y%m%d-%H%M%S')"
    HFT_OUTPUT="${HFT_TEST_DIRECTORY}/output/${stamp}"
    HF_ARTIFACTS="${HFT_OUTPUT}/artifacts"
    HFT_SUITE_DIRECTORY="${HFT_OUTPUT}/suites"
    HF_RUN_LOG="${HFT_OUTPUT}/run.log"
    HFT_RESULT_TSV="${HFT_OUTPUT}/results.tsv"
    mkdir -p "${HF_ARTIFACTS}" "${HFT_SUITE_DIRECTORY}"
    : > "${HF_RUN_LOG}"
    : > "${HFT_RESULT_TSV}"
    export HFT_TEST_DIRECTORY HFT_ROOT HFT_OUTPUT HF_ARTIFACTS HFT_SUITE_DIRECTORY HF_RUN_LOG HFT_RESULT_TSV PROFILE
    TOTAL_PASS=0
    TOTAL_FAIL=0
    TOTAL_WARN=0
    TOTAL_SKIP=0
    hft_log "High-Fortress test run"
    hft_log "root     : ${HFT_ROOT}"
    hft_log "output   : ${HFT_OUTPUT}"
    hft_log "profile  : ${PROFILE}"
    hft_log "host     : $(hostname -s 2>/dev/null || hostname)"
    hft_log ""
}

hft_run_suite() {
    local suite hf_suite_name
    for suite in "${HFT_TEST_DIRECTORY}/suites/"[0-9][0-9]_*.sh; do
        [[ -f "${suite}" ]] || continue
        hf_suite_name="$(basename "${suite}" .sh)"
        export HFT_SUITE_LOG="${HFT_SUITE_DIRECTORY}/${hf_suite_name}.log"
        : > "${HFT_SUITE_LOG}"
        HFT_PASS=0
        HFT_FAIL=0
        HFT_WARN=0
        HFT_SKIP=0
        hft_log ""
        hft_log "════════════════════════════════════════════════════════════════"
        hft_log " SUITE ${hf_suite_name}"
        hft_log "════════════════════════════════════════════════════════════════"
        # shellcheck disable=SC1090
        source "${suite}"
        TOTAL_PASS=$((TOTAL_PASS + HFT_PASS))
        TOTAL_FAIL=$((TOTAL_FAIL + HFT_FAIL))
        TOTAL_WARN=$((TOTAL_WARN + HFT_WARN))
        TOTAL_SKIP=$((TOTAL_SKIP + HFT_SKIP))
        hft_log "suite ${hf_suite_name}: ${HFT_PASS} pass, ${HFT_FAIL} fail, ${HFT_WARN} warn, ${HFT_SKIP} skip"
    done
}

hft_finish() {
    {
        echo "# Rapport de test"
        echo ""
        echo "- **Date** : $(date -Iseconds)"
        echo "- **Profil** : \`${PROFILE}\`"
        echo "- **Dossier** : \`${HFT_OUTPUT}\`"
        echo "- **Dépôt** : \`${HFT_ROOT}\`"
        echo ""
        echo "## Totaux"
        echo ""
        echo "| PASS | FAIL | WARN | SKIP |"
        echo "|------|------|------|------|"
        echo "| ${TOTAL_PASS} | ${TOTAL_FAIL} | ${TOTAL_WARN} | ${TOTAL_SKIP} |"
        echo ""
        if [[ "${TOTAL_FAIL}" -eq 0 ]]; then
            echo "**Résultat : OK** (aucun FAIL)."
        else
            echo "**Résultat : KO** — ${TOTAL_FAIL} FAIL à corriger avant un déploiement."
        fi
        echo ""
        echo "## FAIL"
        echo ""
        if grep -q '^FAIL' "${HFT_RESULT_TSV}"; then
            echo "| ID | Détail |"
            echo "|----|--------|"
            awk -F'\t' '$1=="FAIL"{printf "| `%s` | %s |\n", $2, $3}' "${HFT_RESULT_TSV}"
        else
            echo "_Aucun._"
        fi
        echo ""
        echo "## WARN"
        echo ""
        if grep -q '^WARN' "${HFT_RESULT_TSV}"; then
            echo "| ID | Détail |"
            echo "|----|--------|"
            awk -F'\t' '$1=="WARN"{printf "| `%s` | %s |\n", $2, $3}' "${HFT_RESULT_TSV}"
        else
            echo "_Aucun._"
        fi
        echo ""
        echo "## PASS (aperçu)"
        echo ""
        echo "Voir \`results.tsv\` et \`suites/*.log\` pour le détail complet (${TOTAL_PASS} PASS)."
        echo ""
        echo "## Fichiers"
        echo ""
        echo "- Journal combiné : \`run.log\`"
        echo "- Résultats bruts : \`results.tsv\`"
        echo "- Configs sandbox : \`artifacts/\`"
    } > "${HFT_OUTPUT}/summary.md"

    python3 - "${HFT_OUTPUT}/summary.json" "${TOTAL_PASS}" "${TOTAL_FAIL}" "${TOTAL_WARN}" "${TOTAL_SKIP}" "${PROFILE}" "${HFT_RESULT_TSV}" << 'PY'
import json, sys
out, p, f, w, s, profile, tsv = sys.argv[1:8]
items = []
with open(tsv, encoding="utf-8") as fh:
    for line in fh:
        line = line.rstrip("\n")
        if not line:
            continue
        status, ident, msg = line.split("\t", 2)
        items.append({"status": status, "id": ident, "message": msg})
payload = {
    "profile": profile,
    "pass": int(p),
    "fail": int(f),
    "warn": int(w),
    "skip": int(s),
    "ok": int(f) == 0,
    "results": items,
}
with open(out, "w", encoding="utf-8") as fh:
    json.dump(payload, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
PY

    hft_log ""
    hft_log "════════════════════════════════════════════════════════════════"
    hft_log " TOTAL  pass=${TOTAL_PASS} fail=${TOTAL_FAIL} warn=${TOTAL_WARN} skip=${TOTAL_SKIP}"
    hft_log " Rapport : ${HFT_OUTPUT}/summary.md"
    hft_log "════════════════════════════════════════════════════════════════"
    if [[ "${TOTAL_FAIL}" -eq 0 ]]; then
        exit 0
    fi
    exit 1
}
