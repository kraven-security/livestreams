#!/usr/bin/env python3
"""Fill the upstream OpenCTI .env with freshly generated lab secrets.

Run from the folder holding docker-compose.yml after `cp .env.sample .env`:

    python3 scripts/generate_env_secrets.py [path/to/.env]

Only keys already present in the upstream .env.sample are updated; every
other line is preserved. No secret is printed. Set a known admin password in
.env privately (from your password manager) before the first login.
"""
import base64
import secrets
import sys
import uuid
from pathlib import Path

p = Path(sys.argv[1] if len(sys.argv) > 1 else ".env")
if not p.exists():
    raise SystemExit("Missing .env; run cp .env.sample .env first")

updates = {
    "OPENCTI_ADMIN_EMAIL": "admin@opencti.local",
    "XTM_ONE_ADMIN_EMAIL": "admin@opencti.local",
    "OPENCTI_ADMIN_PASSWORD": secrets.token_urlsafe(24),
    "XTM_ONE_ADMIN_PASSWORD": secrets.token_urlsafe(24),
    "OPENCTI_ADMIN_TOKEN": str(uuid.uuid4()),
    "OPENCTI_HEALTHCHECK_ACCESS_KEY": secrets.token_urlsafe(32),
    "OPENCTI_ENCRYPTION_KEY": base64.b64encode(secrets.token_bytes(32)).decode(),
    "MINIO_ROOT_PASSWORD": secrets.token_urlsafe(24),
    "RABBITMQ_DEFAULT_PASS": secrets.token_urlsafe(24),
    "PLATFORM_REGISTRATION_TOKEN": secrets.token_hex(32),
    "XTM_ONE_SECRET_KEY": secrets.token_hex(32),
    "XTM_ONE_POSTGRES_PASSWORD": secrets.token_urlsafe(24),
    "XTM_COMPOSER_ID": str(uuid.uuid4()),
}

lines = []
found = set()
for line in p.read_text().splitlines():
    key = line.split("=", 1)[0].strip()
    if key in updates and not line.lstrip().startswith("#"):
        lines.append(key + "=" + updates[key])
        found.add(key)
    else:
        lines.append(line)

missing = set(updates) - found
if missing:
    raise SystemExit(
        "Upstream .env.sample changed; inspect missing keys: " + ", ".join(sorted(missing))
    )

p.write_text("\n".join(lines) + "\n")
p.chmod(0o600)
print("Secrets set in .env (not printed). Set a known admin password securely before first login.")
