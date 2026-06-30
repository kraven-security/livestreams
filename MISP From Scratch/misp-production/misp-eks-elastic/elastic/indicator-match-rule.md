# Indicator Match rule + end-to-end validation

Goal: prove the pipeline works — an IOC in MISP causes an alert in Elastic when your
telemetry contains a match. This is the Segment E payoff.

## 1. Make sure detection looks at the ACTIVE IOC index
Kibana → Stack Management → Advanced Settings →
`securitySolution:defaultThreatIndex`. Add the latest destination pattern so rules
query only active IOCs:

```
logs-ti_misp_latest.*
```

(If you used the Filebeat module instead of the Agent integration, add that module's
index pattern, e.g. `logs-ti_*` or your custom `filebeat-*` pattern.)

## 2. Create the Indicator Match rule
Kibana → Security → Rules → Detection rules (SIEM) → Create new rule → **Indicator Match**.
- **Index patterns (your telemetry)**: e.g. `logs-*`, `filebeat-*`, endpoint/network logs
- **Indicator index**: `logs-ti_misp_latest.threat_attributes` (the latest alias)
- **Indicator mapping** (examples):
  - `source.ip`           MATCHES  `threat.indicator.ip`
  - `destination.ip`      MATCHES  `threat.indicator.ip`
  - `dns.question.name`   MATCHES  `threat.indicator.url.domain`
  - `file.hash.sha256`    MATCHES  `threat.indicator.file.hash.sha256`
- Schedule: run every 1–5m with a look-back buffer.

## 3. Plant a controlled test IOC in MISP
- In MISP, create an event, add a **benign, controlled** attribute (a domain/IP/hash
  you own or that is safe to trigger on), tag it so it's in your pull scope (e.g.
  `workflow:state="complete"`), and **publish** the event.
- Wait one poll interval, then confirm it landed:
  ```
  GET logs-ti_misp_latest.threat_attributes/_search
  ```

## 4. Generate matching telemetry → alert fires
- Produce a log line in your telemetry indices containing the test indicator
  (e.g. a DNS query to the test domain).
- Within a rule interval, an alert appears in Security → Alerts.

## 5. Talking point (why "latest" matters)
If you point the rule at the raw source data stream instead of the latest alias,
expired/decayed IOCs still match and you drown in false positives. Pointing at
`logs-ti_misp_latest.*` is the production-correct choice.

## Tease (future episode)
Match → enrichment → automated response (e.g. isolate host / block indicator) via
Elastic Security + Endgame/EDR or a SOAR action.
