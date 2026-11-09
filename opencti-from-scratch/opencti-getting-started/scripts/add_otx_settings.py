#!/usr/bin/env python3
"""Add AlienVault OTX connector settings to the OpenCTI .env.

Run from the folder holding docker-compose.yml after the .env exists:

    python3 scripts/add_otx_settings.py [path/to/.env]

Prompts for the OTX API key without echoing it, keeps an existing connector
UUID (or generates a new UUIDv4) and sets the initial import cutoff to seven
days ago. The cutoff is fixed when you run this; Docker doesn't recalculate
it. If your subscribed Pulses are older, move the date earlier.
"""
import sys
from datetime import datetime, timedelta, timezone
from getpass import getpass
from pathlib import Path
from uuid import uuid4

p = Path(sys.argv[1] if len(sys.argv) > 1 else ".env")
if not p.exists():
    raise SystemExit("Copy .env.sample to .env first")

key = getpass("Paste OTX API key (hidden): ").strip()
if not key or any(ch in key for ch in "\n\r"):
    raise SystemExit("Missing/invalid key")

lines = p.read_text().splitlines()
known = {}
for line in lines:
    if "=" in line and not line.lstrip().startswith("#"):
        k, v = line.split("=", 1)
        known[k.strip()] = v.strip()

values = {
    "ALIENVAULT_API_KEY": key,
    "ALIENVAULT_CONNECTOR_ID": known.get("ALIENVAULT_CONNECTOR_ID") or str(uuid4()),
    "ALIENVAULT_PULSE_START_TIMESTAMP": (
        datetime.now(timezone.utc) - timedelta(days=7)
    ).strftime("%Y-%m-%dT%H:%M:%SZ"),
}

lines = [line for line in lines if line.split("=", 1)[0].strip() not in values]
lines += [f"{k}={v}" for k, v in values.items()]
p.write_text("\n".join(lines) + "\n")
p.chmod(0o600)
print("OTX settings saved to private .env; no secrets printed")
