#!/usr/bin/env bash
# =============================================================================
# File       : core/test-harness.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

hf_ts() { date '+%Y-%m-%d %H:%M:%S'; }

hf_log() {
    local line="[$(hf_ts)] $*"
    printf '%s\n' "$line"
    if [[ -n "${HF_RUN_LOG:-}" ]]; then
        printf '%s\n' "$line" >> "${HF_RUN_LOG}"
    fi
    if [[ -n "${HF_SUITE_LOG:-}" ]]; then
        printf '%s\n' "$line" >> "${HF_SUITE_LOG}"
    fi
}

hf_record() {
    local status="$1"
    local id="$2"
    local msg="$3"
    printf '%s\t%s\t%s\n' "$status" "$id" "$msg" >> "${HF_RESULTS_TSV}"
}

hf_pass() {
    HF_PASS=$((HF_PASS + 1))
    hf_log "PASS  $1 — $2"
    hf_record PASS "$1" "$2"
}

hf_fail() {
    HF_FAIL=$((HF_FAIL + 1))
    hf_log "FAIL  $1 — $2"
    hf_record FAIL "$1" "$2"
}

hf_warn() {
    HF_WARN=$((HF_WARN + 1))
    hf_log "WARN  $1 — $2"
    hf_record WARN "$1" "$2"
}

hf_skip() {
    HF_SKIP=$((HF_SKIP + 1))
    hf_log "SKIP  $1 — $2"
    hf_record SKIP "$1" "$2"
}

hf_section() {
    hf_log ""
    hf_log "── $1 ──"
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

hf_load_project_conf() {
    # shellcheck disable=SC1091
    set +u
    source "${HF_ROOT}/global.conf"
    set -u
}

hf_leftover_envsubst() {
    local file="$1"
    grep -oE '\$\{[A-Z_][A-Z0-9_]*\}' "$file" 2>/dev/null | sort -u || true
}

hf_test_begin() {
    local stamp
    stamp="$(date '+%Y%m%d-%H%M%S')"
    HF_OUT="${HF_TEST_DIR}/output/${stamp}"
    HF_ARTIFACTS="${HF_OUT}/artifacts"
    HF_SUITE_DIR="${HF_OUT}/suites"
    HF_RUN_LOG="${HF_OUT}/run.log"
    HF_RESULTS_TSV="${HF_OUT}/results.tsv"
    mkdir -p "${HF_ARTIFACTS}" "${HF_SUITE_DIR}"
    : > "${HF_RUN_LOG}"
    : > "${HF_RESULTS_TSV}"
    export HF_TEST_DIR HF_ROOT HF_OUT HF_ARTIFACTS HF_SUITE_DIR HF_RUN_LOG HF_RESULTS_TSV PROFILE
    TOTAL_PASS=0
    TOTAL_FAIL=0
    TOTAL_WARN=0
    TOTAL_SKIP=0
    hf_log "High-Fortress test run"
    hf_log "root     : ${HF_ROOT}"
    hf_log "output   : ${HF_OUT}"
    hf_log "profile  : ${PROFILE}"
    hf_log "host     : $(hostname -s 2>/dev/null || hostname)"
    hf_log ""
}

hf_test_run_suites() {
    local suite hf_suite_name
    for suite in "${HF_TEST_DIR}/suites/"[0-9][0-9]_*.sh; do
        [[ -f "${suite}" ]] || continue
        hf_suite_name="$(basename "${suite}" .sh)"
        export HF_SUITE_LOG="${HF_SUITE_DIR}/${hf_suite_name}.log"
        : > "${HF_SUITE_LOG}"
        HF_PASS=0
        HF_FAIL=0
        HF_WARN=0
        HF_SKIP=0
        hf_log ""
        hf_log "════════════════════════════════════════════════════════════════"
        hf_log " SUITE ${hf_suite_name}"
        hf_log "════════════════════════════════════════════════════════════════"
        # shellcheck disable=SC1090
        source "${suite}"
        TOTAL_PASS=$((TOTAL_PASS + HF_PASS))
        TOTAL_FAIL=$((TOTAL_FAIL + HF_FAIL))
        TOTAL_WARN=$((TOTAL_WARN + HF_WARN))
        TOTAL_SKIP=$((TOTAL_SKIP + HF_SKIP))
        hf_log "suite ${hf_suite_name}: ${HF_PASS} pass, ${HF_FAIL} fail, ${HF_WARN} warn, ${HF_SKIP} skip"
    done
}

hf_test_finish() {
    {
        echo "# Rapport de test"
        echo ""
        echo "- **Date** : $(date -Iseconds)"
        echo "- **Profil** : \`${PROFILE}\`"
        echo "- **Dossier** : \`${HF_OUT}\`"
        echo "- **Dépôt** : \`${HF_ROOT}\`"
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
        if grep -q '^FAIL' "${HF_RESULTS_TSV}"; then
            echo "| ID | Détail |"
            echo "|----|--------|"
            awk -F'\t' '$1=="FAIL"{printf "| `%s` | %s |\n", $2, $3}' "${HF_RESULTS_TSV}"
        else
            echo "_Aucun._"
        fi
        echo ""
        echo "## WARN"
        echo ""
        if grep -q '^WARN' "${HF_RESULTS_TSV}"; then
            echo "| ID | Détail |"
            echo "|----|--------|"
            awk -F'\t' '$1=="WARN"{printf "| `%s` | %s |\n", $2, $3}' "${HF_RESULTS_TSV}"
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
    } > "${HF_OUT}/summary.md"

    python3 - "${HF_OUT}/summary.json" "${TOTAL_PASS}" "${TOTAL_FAIL}" "${TOTAL_WARN}" "${TOTAL_SKIP}" "${PROFILE}" "${HF_RESULTS_TSV}" << 'PY'
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

    hf_log ""
    hf_log "════════════════════════════════════════════════════════════════"
    hf_log " TOTAL  pass=${TOTAL_PASS} fail=${TOTAL_FAIL} warn=${TOTAL_WARN} skip=${TOTAL_SKIP}"
    hf_log " Rapport : ${HF_OUT}/summary.md"
    hf_log "════════════════════════════════════════════════════════════════"
    if [[ "${TOTAL_FAIL}" -eq 0 ]]; then
        exit 0
    fi
    exit 1
}
