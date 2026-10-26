#!/usr/bin/env bash
# Run off-screen from a disposable lab host. Creates only kit-local config.
set -euo pipefail
cd "$(dirname "$0")/.."
for program in npm docker; do
  command -v "$program" >/dev/null || { printf 'Missing prerequisite: %s\n' "$program" >&2; exit 1; }
done
docker compose version
repo=repos/MISP-Fleet-Commander
(cd "$repo/web" && npm ci && npm run buildproduction)
test -f "$repo/backend/application/dist/index.html"
repos/misp-guard/.venv/bin/python - <<'PY'
from pathlib import Path
import json, os, secrets, yaml
p=Path('repos/MISP-Fleet-Commander')
# Upstream uses the pre-Marshmallow-4 name for a deserialization default.
# Keep the equivalent behavior with current dependencies; safe on reruns.
schema=p/'backend/application/marshmallowSchemas.py'
source=schema.read_text()
old='server_info = fields.Nested(lambda: ServerQuerySchema, validate=existOrNone, missing=None)'
new='server_info = fields.Nested(lambda: ServerQuerySchema, validate=existOrNone, load_default=None)'
if old in source:
    schema.write_text(source.replace(old,new))
elif new not in source:
    raise SystemExit('Fleet ServerSchema changed upstream; review the Marshmallow compatibility patch.')
cfg=yaml.safe_load((p/'docker-compose.yml').read_text())
cfg['services']['backend']['ports']=['127.0.0.1:5001:5001']
secret=secrets.token_urlsafe(32)
for name in ('backend','workers'):
    env=cfg['services'][name]['environment']
    env=[s for s in env if not s.startswith('SECRET_KEY=')]
    env.append('SECRET_KEY='+secret)
    cfg['services'][name]['environment']=env
out=p/'compose.part12.json'
if out.exists():
    # Keep a stable secret on reruns.
    old=json.loads(out.read_text())
    for name in ('backend','workers'):
        oldkey=next(s for s in old['services'][name]['environment'] if s.startswith('SECRET_KEY='))
        cfg['services'][name]['environment']=[oldkey if s.startswith('SECRET_KEY=') else s for s in cfg['services'][name]['environment']]
out.write_text(json.dumps(cfg,indent=2)+'\n')
os.chmod(out,0o600)
PY
cd "$repo"
docker compose -f compose.part12.json config --quiet
docker compose -f compose.part12.json build
docker compose -f compose.part12.json up -d redis
docker compose -f compose.part12.json run --rm backend flask db upgrade
set +x
read -r -s -p 'Choose a new Fleet demo admin password: ' FLEET_DEMO_PASSWORD
printf '\n'
if [ -z "$FLEET_DEMO_PASSWORD" ]; then printf 'Password must not be empty.\n' >&2; exit 1; fi
docker compose -f compose.part12.json run --rm backend flask user change_pw admin@admin.test "$FLEET_DEMO_PASSWORD"
unset FLEET_DEMO_PASSWORD
docker compose -f compose.part12.json up -d backend workers
docker compose -f compose.part12.json ps
printf 'Open http://localhost:5001 on the Docker host; log in with admin@admin.test and your chosen password.\n'
