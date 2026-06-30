# Elastic Method 1 — Elastic Agent + Threat Intel "MISP" integration (`ti_misp`)

This is the **recommended production path**. The integration pulls from MISP's REST
API and, unlike the raw Filebeat module, ships a Transform that keeps only **active,
unexpired** IOCs in a "latest" index — so your detection rules don't fire on decayed
indicators.

You're shipping to an **existing/external Elastic**, so we enroll an Elastic Agent
**inside EKS** (closest to MISP, pulls the internal service) into your external Fleet.

## 1. Create the MISP sync user + auth key
Run `scripts/create-misp-sync-user.sh` (read-only role). Copy the auth key.

## 2. Enroll an in-cluster Elastic Agent into your external Fleet
In Kibana → Fleet → Agents → Add agent, copy your **Fleet URL** and an
**enrollment token**, then deploy a managed Agent in the cluster:

```bash
kubectl -n "$NAMESPACE" create secret generic fleet-enroll \
  --from-literal=FLEET_URL="https://your-fleet-server:8220" \
  --from-literal=FLEET_ENROLLMENT_TOKEN="REPLACE_ME"
```

Deploy the Agent (managed mode) as a single replica Deployment using
`docker.elastic.co/elastic-agent/elastic-agent:<your-version>` with env
`FLEET_ENROLL=1`, `FLEET_URL`, `FLEET_ENROLLMENT_TOKEN` from that secret. (A poller
integration only needs one Agent, not a DaemonSet.)

## 3. Add the MISP integration to that Agent's policy
Kibana → Integrations → search **"Threat Intel"** → **MISP** → Add.
Configure:
- **URL**: `http://misp-nginx.<namespace>.svc.cluster.local` (internal service)
- **API Key (auth)**: the MISP sync-user auth key
- **SSL verification**: `none` for the internal HTTP hop (or `full` + CA if internal HTTPS)
- **Interval**: e.g. `5m`; **Initial interval / look-back**: e.g. `24h`
- **Filters**: restrict to the indicator types and a publish/workflow tag you trust,
  e.g. types `md5,sha256,url,domain,ip-src,ip-dst` and tag `workflow:state="complete"`
- **IOC Expiration Duration**: leave the default (90d) as a fail-safe for IOCs that
  never decay

## 4. What you get
- Source data stream: `logs-ti_misp.threat_attributes-*`
- A Transform maintains the **latest/active** set:
  `logs-ti_misp_latest.dest_threat_attributes-*`, aliased as
  `logs-ti_misp_latest.threat_attributes`
- Prebuilt MISP dashboards under Kibana → Analytics → Dashboards
- ILM on the source stream prevents unbounded growth

## 5. Point detection at the LATEST alias
When you build the Indicator Match rule (see `indicator-match-rule.md`), use the
**latest alias**, not the raw source index — this is what avoids false positives
from expired IOCs.

---

### Method 1 vs Method 2 — which to demo as the recommendation
| | Agent `ti_misp` (this file) | Filebeat module (`filebeat-collector.yaml`) |
|---|---|---|
| IOC decay/expiry | built-in Transform + latest index | you handle it |
| Management | Fleet (central) | static config |
| Dashboards | prebuilt | none |
| Footprint | heavier | light |
| Best for | **production default** | lightweight / no-Fleet / edge |
