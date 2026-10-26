#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p repos output
for pair in cudeso/misp-scraper MISP/misp-guard MISP/misp-mcp MISP/MISP-Fleet-Commander; do
  name=${pair##*/}
  if [ ! -d "repos/$name/.git" ]; then
    git clone "https://github.com/$pair.git" "repos/$name"
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
python3.12 -m venv repos/misp-mcp/.venv
repos/misp-mcp/.venv/bin/python -m pip install -e repos/misp-mcp
printf 'Preparation installed dependencies. Rehearse before streaming; no live MISP calls made here.\n'
