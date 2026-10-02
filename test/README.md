# Tests High-Fortress User

Ubuntu 26.04. Banc d’essai statique : pas d’installation du poste, pas de root. Il vérifie la syntaxe, les étapes, les fonctions conservées, les interdits du poste, les secrets hors git, le SQL et le routeur.

Le lanceur est le même que celui du serveur. Les assertions (`hf_pass`, `hf_fail`, `hf_warn`, `hf_skip`) sont dans `core/test-harness.sh`. Les contrôles du poste restent dans `test/suites/`.

## Lancer

Dans le clone :

```bash
bash test/run.sh
```

## Sortie

Chaque run crée un dossier horodaté :

```
test/output/YYYYMMDD-HHMMSS/
  summary.md      ← lire ça en premier
  summary.json
  run.log
  results.tsv
  suites/*.log
  artifacts/
```

Code de sortie : `0` si 0 FAIL (WARN autorisés), `1` sinon.

## Périmètre

- Inclus : `scripts/run.sh`, `core/lib.sh`, `global.conf`, `system/`, `service/`, `template/`, et les contrôles du dépôt privé (routeur, SQL, secrets)
- Le profil enregistré est `WORKSTATION`. `--profile` d’un serveur est refusé.
