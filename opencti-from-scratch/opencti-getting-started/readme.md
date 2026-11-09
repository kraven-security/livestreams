# OpenCTI From Scratch: Docker Setup + Free Threat Intel (AlienVault OTX)

Lab kit for the Kraven Security livestream that deploys **OpenCTI Community Edition** with Docker, connects it to a free **AlienVault OTX** account for real community Pulses, and tours the UI: reports, indicators, observables, ATT&CK techniques and the knowledge graph. It ends with a comparison against MISP.

By the end you should be able to:

- explain what OpenCTI is and how its architecture fits together
- start a local lab stack from the official Docker deployment
- import third-party intelligence through a connector
- navigate the UI and follow STIX relationships between entities
- decide when to use OpenCTI alongside MISP

There's no custom application code. The stream runs the official OpenCTI Compose stack and adds one connector. Files in this folder:

| File | Purpose |
| --- | --- |
| [docker-compose.yml](docker-compose.yml) | Official OpenCTI stack from [OpenCTI-Platform/docker](https://github.com/OpenCTI-Platform/docker) (commit `60285ad`; unchanged apart from a header comment) |
| [.env.sample](.env.sample) | Upstream environment template. Copy it to `.env` |
| [rabbitmq.conf](rabbitmq.conf) | RabbitMQ settings the stack mounts (`max_message_size`, `consumer_timeout`) |
| [scripts/preflight.sh](scripts/preflight.sh) | Check tool versions, disk, RAM, port 8080 and `vm.max_map_count` |
| [scripts/generate_env_secrets.py](scripts/generate_env_secrets.py) | Fill the upstream `.env` with generated lab secrets (prints nothing) |
| [scripts/set-sysctl.sh](scripts/set-sysctl.sh) | Set `vm.max_map_count` for Elasticsearch and keep it after reboot |
| [scripts/add_otx_settings.py](scripts/add_otx_settings.py) | Add the OTX API key, connector UUID and import cutoff to `.env` |
| [compose/connector-alienvault.yml](compose/connector-alienvault.yml) | AlienVault OTX connector service (paste in, or use as an override) |

> **Lab only.** Use a disposable Ubuntu VM. Never commit or share `.env`, and never show tokens, API keys or `docker compose config` output on screen.

## Requirements

- Ubuntu Linux host or VM (on macOS, a well-resourced Linux VM is the most predictable option)
- Docker Engine with the Compose v2 plugin, Git, Python 3 and OpenSSL
- Internet access for image pulls, MITRE data and OTX
- Port 8080 free
- A free [AlienVault OTX](https://otx.alienvault.com/) account

**Sizing.** The official production docs list at least 8 GB RAM each for Elasticsearch and the OpenCTI core, plus dependencies. For a smooth all-in-one lab, aim for **24–32 GB RAM, 4–8 vCPU and at least 60 GB free SSD**. This is a lab suggestion, not a vendor minimum. Smaller hosts need tuning and can stall during setup.

## Architecture

```text
Browser → OpenCTI platform (web UI + GraphQL API)
               ↓
      Elasticsearch / OpenSearch   indexed intelligence
      Redis                        cache / stream coordination
      S3-compatible store (MinIO)  files / artifacts
      RabbitMQ (job queue) → Python workers (background writes)
                                 ↑
                      Python connectors (import / export / enrichment)

Optional upstream add-ons: XTM Integrations Manager (composer); XTM One + its PostgreSQL/worker
```

- **Platform:** browser UI and GraphQL API.
- **Workers:** RabbitMQ consumers that do asynchronous writes.
- **Connectors:** external imports, internal enrichments, file imports/exports and streams.
- **Elasticsearch/OpenSearch:** searchable data. **Redis:** caching and streams. **MinIO:** stored files. **RabbitMQ:** message broker.
- **XTM One:** the current upstream default Compose file starts XTM One containers. They're expected, not an install error, and this lab doesn't use them.

## 1. Preflight

Clone this repo onto the lab host, then:

```bash
bash scripts/preflight.sh
```

## 2. Get the Compose stack

**Option A: use this folder.** [docker-compose.yml](docker-compose.yml), [.env.sample](.env.sample) and [rabbitmq.conf](rabbitmq.conf) are copies of the official deployment files at commit `60285ad`:

```bash
cd opencti-from-scratch/opencti-getting-started
cp .env.sample .env
```

**Option B: clone the latest upstream** (as the [official docs](https://docs.opencti.io/latest/deployment/installation/#using-docker) do):

```bash
mkdir -p ~/labs && cd ~/labs
git clone https://github.com/OpenCTI-Platform/docker.git opencti-docker
cd opencti-docker
git rev-parse --short HEAD   # record this; the upstream repo changes over time
cp .env.sample .env
```

If you use Option B, run the commands below from `~/labs/opencti-docker` and give the full path to this folder's `scripts/` and `compose/`.

What the stack contains:

- **Dependencies:** Redis, Elasticsearch 8 (single node, `thread_pool.search.queue_size=5000`, heap set by `ELASTIC_MEMORY_SIZE`), Silo/MinIO (S3) and RabbitMQ (with `rabbitmq.conf`)
- **OpenCTI:** `opencti` platform on `${OPENCTI_PORT}` (8080) and 3 `worker` replicas
- **Built-in connectors:** STIX/CSV/TXT export; STIX, document, YARA and external-reference import; document analysis
- **Default data:** OpenCTI Datasets and MITRE ATT&CK
- **Extras you can ignore:** `xtm-composer`, `xtm-one`, `xtm-one-worker`, `pgsql-xtm-one` and `rsa-key-generator`
- **Data:** named volumes `esdata`, `s3data`, `redisdata` and `amqpdata` (plus `rsakeys` and `pgsqlxtmonedata`)

Images use `:latest`. Pin them to a tested release before a live session, and don't upgrade blindly right before one.

## 3. Generate secrets in `.env`

```bash
python3 scripts/generate_env_secrets.py
```

The script only updates keys it recognises from the upstream `.env.sample`, keeps everything else, sets the file to `0600` and prints no secrets. If upstream renames a key, it stops and lists the missing keys.

The generated admin password isn't printed. **Before first login, edit `.env` privately and set `OPENCTI_ADMIN_PASSWORD` to a strong password from your password manager.** Change `OPENCTI_HOST` / `OPENCTI_PORT` if your browser isn't on the lab host.

## 4. Kernel setting and Compose validation

```bash
bash scripts/set-sysctl.sh
docker compose config --quiet
```

On Docker Desktop the kernel lives in Docker's VM, so the host `sysctl` won't reach containers; use your Docker Desktop version's VM setting instead. An invalid `OPENCTI_ADMIN_TOKEN` (it must be a UUIDv4) blocks startup.

## 5. Start the stack

```bash
docker compose pull
docker compose up -d
docker compose ps
```

The first pull and initialization can take a long time. Wait until `opencti` and its workers report healthy/running.

If something isn't healthy, read the logs. Check them for secrets before you share them:

```bash
docker compose logs --tail=80 opencti
docker compose logs --tail=80 elasticsearch
docker compose logs --tail=80 rabbitmq
```

Open **http://localhost:8080** and sign in with `OPENCTI_ADMIN_EMAIL` and the password you set. If you access the lab from another machine, keep it behind a trusted network or VPN. Don't expose plain HTTP publicly.

## 6. Connect AlienVault OTX

OTX gives you community intelligence, not validated detections. Treat every indicator as a claim to verify.

**6.1 Create an account and subscribe to Pulses.** Sign up at [otx.alienvault.com](https://otx.alienvault.com/). Open 2–3 recent, clearly sourced Pulses that contain observables (IPs, domains, hashes) and **Subscribe/Follow** each one. The connector pulls subscribed Pulses only; having an account isn't enough.

**6.2 Get your API key.** Go to profile → Settings (or API settings) and copy your OTX API key. Keep it in a password manager.

**6.3 Add OTX settings to `.env`:**

```bash
python3 scripts/add_otx_settings.py
```

The script asks for the key without echoing it, creates a stable UUIDv4 connector ID and sets `ALIENVAULT_PULSE_START_TIMESTAMP` to seven days ago. That date is fixed when you run the script. If your Pulses are older, edit the date in `.env` to an earlier one.

**6.4 Add the connector service.** Either:

- **Paste it:** copy the `connector-alienvault:` block from [compose/connector-alienvault.yml](compose/connector-alienvault.yml) into `docker-compose.yml` under top-level `services:`, next to `connector-mitre` and `connector-opencti`, with two-space indentation. This is the version shown on stream.
- **Or use it as an override:** add `-f docker-compose.yml -f compose/connector-alienvault.yml` to each `docker compose` command below.

Key settings:

- `OPENCTI_TOKEN` lets the connector write to OpenCTI.
- `ALIENVAULT_API_KEY` authenticates to OTX.
- `CONNECTOR_ID` is the connector's unique identity.
- `ALIENVAULT_PULSE_START_TIMESTAMP` limits the first backfill.

The URL uses the container hostname `opencti`, not `localhost`. Pin a connector image tag that matches your platform release.

**6.5 Start the connector** once OpenCTI is healthy:

```bash
docker compose config --quiet
docker compose pull connector-alienvault
docker compose up -d connector-alienvault
docker compose ps connector-alienvault
docker compose logs --tail=50 connector-alienvault   # check for secrets before sharing
```

A running container doesn't mean the import has finished. Check progress under **Data Management → Ingestion → Connectors** (or **Integrations → Deployed**, depending on version): the connector should be registered and show its last runs and processing results.

**6.6 Verify the imported data.** Open an OTX Pulse under **Analyses → Reports**. Check its source and external reference, look at its Indicators and Observables, then pivot into **Knowledge**/graph. Compare it with the original Pulse on OTX. ATT&CK relationships only appear if the Pulse has them.

**No records?** Check that:

- you subscribed to Pulses
- they were published after the cutoff date
- the key is valid and the connector can reach OTX
- the work queues are processing
- the logs show no rate-limit (429) or upstream (504) errors

Not every Pulse produces useful graph links.

## 7. UI tour

| Area | Where | What to look at |
| --- | --- | --- |
| Dashboard | Home | Intrusion set, malware, report and indicator tiles; activity charts; custom dashboards. Fresh instances look sparse until imports run. |
| Threats | Threats → Intrusion sets | Search APT29 (after MITRE import). Overview: creator, markings, confidence, external refs. Knowledge: linked context. |
| Graph | Entity Knowledge view or an Investigation | Focus a node, expand, filter relationships; what `uses`, `targets` and `indicates` actually mean. |
| ATT&CK | Techniques → Attack patterns | Search **T1059** (Command and Scripting Interpreter) and its related intrusion sets or malware. TTPs aren't the same as raw IPs or domains. |
| Observations | Observations | Observable (something seen) vs indicator (a detection assertion, can hold a STIX pattern). |
| Analyses | Analyses → Reports | Overview, Knowledge and Content tabs; tracing evidence and sources; Diamond Model where supported. |
| Data & admin | Data Management → Ingestion → Connectors; Settings | AlienVault OTX, MITRE and OpenCTI Datasets status; TAXII, CSV feeds, live streams; roles. |

**Optional synthetic indicator:** create an Indicator named `Demo IPv4 test` with the pattern below and a lab-only label. `198.51.100.42` is RFC 5737 documentation space, not a malicious IP. Delete it afterwards.

```text
[ipv4-addr:value = '198.51.100.42']
```

## 8. OpenCTI vs MISP

| | MISP | OpenCTI |
| --- | --- | --- |
| Main strength | IoC/event-centric collaboration, sharing groups, correlation, sync | STIX 2.1 entity-and-relationship graph for multi-source analysis and investigations |
| Data model | Event → attributes / objects / tags / galaxies | STIX domain objects, observables, indicators and typed relationships |
| Sharing | Mature community and peer-instance synchronization | STIX 2.1, TAXII, live streams, GraphQL, connectors (including a MISP import connector) |

Neither label is the whole story. MISP also has event graphs, sightings, taxonomies and galaxies, and OpenCTI also handles indicators and feeds. A common pattern is MISP for operational sharing and OpenCTI for broader context and graph exploration, but that's one option, not a required architecture.

## 9. Features worth knowing

- STIX 2.1 knowledge graph with typed relationships, visual pivoting and investigations
- MITRE ATT&CK technique mapping
- Analyst reports with evidence and provenance
- Confidence and TLP/markings
- Indicators, observables and sightings
- Connector catalog and lifecycle
- TAXII, live streams and CSV feeds
- Dashboards and a role-aware UI

This lab covers Community Edition only. Enterprise and AI features aren't included.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Elasticsearch exits | `vm.max_map_count`, free RAM, heap settings, Docker resource limits |
| OpenCTI never healthy | Service logs (privately) and the health of its dependencies |
| Connector absent or not importing | Deployed status, connector logs, outbound network; give the import time |
| Token invalid | `OPENCTI_ADMIN_TOKEN` must be a UUIDv4 |
| Port 8080 taken | Free the port, or change the Compose port and base URL together |
| Low memory | Stop other services or use a larger host; only use a Compose override you've tested |
| Unexpected XTM One containers | These are normal in the current upstream default |

## Cleanup

```bash
docker compose down        # stops the stack, keeps data in named volumes
```

`docker compose down -v` **deletes all lab data**. Only run it if you want to start over.

## Next episode

**MISP → OpenCTI:** ingest MISP events into the STIX knowledge graph with the MISP connector. Covers credentials, filtering, TLP and duplicate handling.

## References

- [OpenCTI installation](https://docs.opencti.io/latest/deployment/installation/) · [Platform overview](https://docs.opencti.io/latest/deployment/overview/) · [Connectors](https://docs.opencti.io/latest/deployment/connectors/)
- [OpenCTI Docker repo](https://github.com/OpenCTI-Platform/docker) · [.env.sample](https://github.com/OpenCTI-Platform/docker/blob/master/.env.sample)
- [Getting started / UI](https://docs.opencti.io/latest/usage/getting-started/) · [UI overview](https://docs.opencti.io/latest/usage/overview/) · [Graphs](https://docs.opencti.io/latest/usage/graphs/) · [Automated imports](https://docs.opencti.io/latest/usage/import/getting-started/) · [Data sharing](https://docs.opencti.io/latest/deployment/integrations/)
- [AlienVault connector](https://github.com/OpenCTI-Platform/connectors/tree/master/external-import/alienvault) · [Connector Compose sample](https://github.com/OpenCTI-Platform/connectors/blob/master/external-import/alienvault/docker-compose.yml) · [XTM Hub listing](https://hub.filigran.io/en/cybersecurity-solutions/opencti-integrations/alienvault)
- [OTX](https://otx.alienvault.com/)
- [MISP features](https://misp-project.org/features/) · [MISP documentation](https://www.misp-project.org/documentation/)
