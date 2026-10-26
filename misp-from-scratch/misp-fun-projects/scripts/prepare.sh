#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for program in git python3.12 curl; do
  command -v "$program" >/dev/null || { printf 'Missing prerequisite: %s\n' "$program" >&2; exit 1; }
done
mkdir -p repos output
for pair in cudeso/misp-scraper MISP/misp-guard MISP/misp-mcp MISP/MISP-Fleet-Commander; do
  name=${pair##*/}
  expected=$(python3.12 -c 'import json,sys; print(json.load(open("source-revisions.json"))[sys.argv[1]])' "$name")
  if [ ! -d "repos/$name/.git" ]; then
    git clone "https://github.com/$pair.git" "repos/$name"
    git -C "repos/$name" checkout --detach "$expected"
  fi
  actual=$(git -C "repos/$name" rev-parse HEAD)
  if [ "$actual" != "$expected" ]; then
    printf 'Unexpected revision in %s. Preserve your work and use a fresh extraction of the kit.\n' "$name" >&2
    exit 1
  fi
done
: > output/rehearsal-revisions.txt
for name in misp-scraper misp-guard misp-mcp MISP-Fleet-Commander; do
  printf '%s ' "$name" >> output/rehearsal-revisions.txt
  git -C "repos/$name" rev-parse HEAD >> output/rehearsal-revisions.txt
done
python3.12 -m venv repos/misp-scraper/.venv
repos/misp-scraper/.venv/bin/python -m pip install -r repos/misp-scraper/requirements.txt
python3.12 -m venv repos/misp-guard/.venv
repos/misp-guard/.venv/bin/python -m pip install -r repos/misp-guard/src/requirements.txt pytest pytest-asyncio
python3.12 -m venv --clear repos/misp-mcp/.venv
repos/misp-mcp/.venv/bin/python -m pip install 'mcp[cli]==1.30.0' -e repos/misp-mcp
for name in misp-scraper misp-guard misp-mcp; do
  "repos/$name/.venv/bin/python" -m pip check
  "repos/$name/.venv/bin/python" -m pip freeze > "output/$name-packages.txt"
done
printf 'Preparation installed dependencies. Rehearse before streaming; no live MISP calls made here.\n'
