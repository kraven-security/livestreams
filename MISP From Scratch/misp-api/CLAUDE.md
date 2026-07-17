# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a single Jupyter notebook (`misp-api-livestream.ipynb`) designed as a live-streaming demo for the Kraven Security MISP series. It demonstrates the full threat-intel lifecycle using **PyMISP** against a local throwaway MISP instance.

## Setup

Install dependencies (run once, off-air):
```bash
pip install pymisp pandas requests
```

Set the required environment variable before launching Jupyter:
```bash
export MISP_KEY="your-throwaway-key"   # macOS/Linux
# setx MISP_KEY "your-throwaway-key"   # Windows (new terminal after)
```

Launch the notebook:
```bash
jupyter notebook misp-api-livestream.ipynb
```

## Notebook Structure & Run Order

**Cell execution order matters** — Section 3 creates a MISP event whose `id` is referenced by later cells. Always run top-to-bottom.

| Section | Purpose |
|---------|---------|
| Config cell | Sets `MISP_URL`, reads `MISP_KEY` from env, declares `created = None` |
| 1 — Setup | `PyMISP` connection, version check |
| 2 — Search & Read | Query attributes/events, pandas DataFrame export |
| 3 — Write | Creates a demo `MISPEvent` with attributes, objects, and galaxy tags; stores result in `created` |
| 4 — Export & Integrate | `return_format='suricata'`/`'csv'`/etc. exports |
| 5 — Automate | Reusable `export_fresh_iocs()` pipeline function |
| Appendix | Raw `requests` REST calls showing what PyMISP does underneath |
| Cleanup | `misp.delete_event(created.id)` — run between takes |

## Pre-stream Checklist

1. Run the Setup cell off-air to confirm the MISP connection.
2. **Kernel → Restart & Clear Output** before going live so you start with a clean slate.
3. Run cleanup at the end of each take to reset the instance.

## Key Conventions

- `MISP_URL` defaults to `https://localhost` (lab VM with self-signed cert).
- `MISP_VERIFY = False` suppresses SSL warnings for the self-signed cert — intentional for the demo environment.
- `pythonify=True` on search calls returns `MISPEvent`/`MISPAttribute` objects; omitting it returns raw JSON dicts.
- The `created` variable is declared at config time (`= None`) so the cleanup cell never raises `NameError` even if Section 3 was skipped.
