# MISP Production Readiness Checklist

A walkthrough checklist for taking a MISP instance from "it runs" to production-ready.
Each item says **what** to do, **why** it matters, and **how** — a MISP setting key, a
UI path, or an infrastructure lever.

Items are tagged by whether the Terraform/Kubernetes stack in this repo already wires
them, or whether they're yours to configure:

- **`WIRED`** — already provisioned by this stack's IaC.
- **`CONFIGURE`** — your action, in the MISP UI or as an infra lever.
- **`CRITICAL`** — don't skip; data-loss or exposure risk.

MISP setting keys live under **Administration → Server Settings & Maintenance**.

---

## 01 · Identity & Access

MISP holds your organisation's threat intelligence and its sharing relationships. Who
can log in — and what they can do once in — is the first control plane.

- **Change the default admin credentials** — `CONFIGURE` `CRITICAL`
  The generated admin password gets you in once; leaving it (or a shared team password)
  is the most common way a lab "goes to prod" with a known credential.
  *How:* Log in, change the password immediately, set a real admin email.
  *Administration → List Users.*

- **Enforce a real password policy** — `CONFIGURE`
  Default minimums are permissive. Analysts reuse passwords; MISP is internet-facing
  behind the ALB.
  *Set:* `Security.password_policy_length` ≥ 16, `Security.password_policy_complexity`,
  `Security.require_password_confirmation = true`.

- **Require MFA (or SSO)** — `CONFIGURE` `CRITICAL`
  A password alone protects your entire intel repository and its sync links to partners.
  MFA is the single biggest account-takeover reducer.
  *How:* Enable TOTP with `Security.otp_required = true`, or wire external auth (LDAP /
  SAML / OIDC / Entra ID) and disable local password login for federated users.

- **Least-privilege roles** — `CONFIGURE`
  The `sync`, `publish`, and `admin` permissions are powerful. Most analysts need none of
  them. Separate org-admins from site-admins.
  *How:* Build scoped roles (*Administration → List Roles*) — grant publish/sync only to
  the accounts that genuinely push data.

- **Govern API auth keys** — `CONFIGURE`
  Automation keys are long-lived credentials that bypass the login page. Unscoped,
  non-expiring keys are a standing risk.
  *Set:* `Security.advanced_authkeys = true` for per-key expiry, comments, and
  IP allow-listing; issue read-only keys where possible and rotate on a schedule.

- **Session & brute-force controls** — `CONFIGURE`
  Idle sessions and unlimited login attempts widen the window for hijack and
  credential-stuffing.
  *Set:* Tune `Security.session_timeout`, throttle with the built-in `SecureAuth` limits,
  and enable `Security.log_each_individual_auth_failure`.

---

## 02 · Application Security

MISP-specific settings that close server-side attack surface and make the app behave
correctly behind a TLS-terminating load balancer.

- **Set the canonical base URL** — `WIRED` `CONFIGURE` `CRITICAL`
  A wrong `baseurl` breaks CSRF tokens, generated links, and API callbacks — the classic
  "redirect loop / CSRF error behind a load balancer".
  *How:* The stack seeds `BASE_URL=https://<hostname>`; confirm `MISP.baseurl` and
  `MISP.external_baseurl` match your real HTTPS hostname.

- **Take the instance live** — `CONFIGURE`
  MISP ships able to sit in a maintenance/"not live" mode; a production instance should be
  explicitly live so background processing and access behave normally.
  *Set:* `MISP.live = true`.

- **Block SSRF via the REST client** — `CONFIGURE` `CRITICAL`
  MISP's built-in REST client can be pointed at arbitrary URLs — a server-side request
  forgery vector into your VPC and cloud metadata.
  *Set:* `Security.rest_client_enable_arbitrary_urls = false`.

- **Restrict local feed / file access** — `CONFIGURE`
  Local-file feeds can be abused to read files off the server (LFI). Unless you
  deliberately use them, turn the capability off.
  *Set:* `Security.disable_local_feed_access = true`, and keep
  `Security.allow_unsafe_apikey_named_param = false`.

- **Reduce module attack surface** — `CONFIGURE`
  Every enabled enrichment/import/export module is code paths and outbound calls you now
  own. Disable what you don't use.
  *How:* Prune enabled `Plugin.Enrichment_*` / import / export modules to only those your
  analysts actually run.

- **Security response headers** — `WIRED` `CONFIGURE`
  Defence-in-depth against clickjacking, MIME-sniffing, and downgrade attacks.
  *How:* nginx already sets `X-Frame-Options`, `X-Content-Type-Options`, etc. (see
  `k8s/04b-nginx-configmap.yaml`) — add `Strict-Transport-Security` (HSTS) at the ALB or
  nginx for HTTPS-only enforcement.

---

## 03 · Secrets & Crypto Material

The keys that encrypt data at rest and sign your notifications. Two of these must never
be lost — losing them is unrecoverable.

- **Back up the encryption key & salt — off-site** — `WIRED` `CRITICAL`
  `ENCRYPTION_KEY` and `SECURITY_SALT` encrypt sensitive values (auth keys, connection
  secrets) in the DB. Lose them and every encrypted value — and often the instance — is
  unrecoverable, even with a DB backup.
  *How:* The stack generates them and stores them in AWS Secrets Manager
  (`misp/instance-secrets`). Export a copy to a separate, access-controlled vault. Never
  rotate `salt` after data exists.

- **Encrypt sensitive data at rest in the DB** — `WIRED`
  Without an app-level encryption key, credentials MISP stores (e.g. server sync keys) sit
  in the database in the clear.
  *How:* Provided as `Security.encryption_key` from the generated `ENCRYPTION_KEY`; RDS
  storage encryption (KMS) is on underneath it too.

- **Configure GnuPG for signed/encrypted email** — `CONFIGURE`
  Notification emails carry intel and links; signing proves authenticity and encryption
  protects TLP-restricted content in transit to inboxes.
  *Set:* `GnuPG.email`, `GnuPG.homedir`, `GnuPG.binary` (passphrase is wired via secret),
  then publish the instance public key. Consider S/MIME as an alternative.

- **Pin crypto across replicas** — `WIRED`
  If each web replica generates its own salt/UUID, scaling out produces CSRF errors and
  split-brain sessions.
  *How:* `ENCRYPTION_KEY`, `SECURITY_SALT`, `MISP_UUID`, and `ADMIN_ORG_UUID` are pinned in
  Secrets Manager so every pod agrees — this is what makes horizontal scaling safe.

---

## 04 · Data & Sharing Governance

MISP is a sharing platform — its default distribution and tagging decide what leaves your
organisation. Governance here prevents accidental disclosure.

- **Set conservative default distribution** — `CONFIGURE` `CRITICAL`
  If the default distribution is broad, analysts can over-share intel to connected
  instances/communities by simply not changing a dropdown.
  *Set:* Default to your organisation only, then widen deliberately:
  `MISP.default_event_distribution`, `MISP.default_attribute_distribution`.

- **Define your organisation model** — `CONFIGURE`
  A clean local/remote org structure underpins every sharing and permission decision
  downstream.
  *How:* Set the host org and add partner orgs (*Administration → List Organisations*);
  confirm `MISP.host_org_id`.

- **Use sharing groups for controlled release** — `CONFIGURE`
  Sharing groups give per-partner granularity instead of the blunt community/all levels —
  the right tool for "share with these three orgs only".
  *How:* Model your trust relationships as sharing groups before you connect any sync
  servers.

- **Enforce TLP/PAP tagging** — `CONFIGURE`
  Handling caveats only work if they're present. Untagged data gets mishandled by both
  humans and automation downstream.
  *How:* Enable the `tlp` and `PAP` taxonomies and make tagging part of your publish
  workflow. *Global Actions → List Taxonomies.*

- **Curate feeds before ingesting** — `CONFIGURE`
  Feeds vary wildly in quality; blindly ingesting to events pollutes correlation and burns
  analyst trust.
  *How:* Enable only trusted feeds, prefer *cache* over *store* until vetted, and review.
  *Sync Actions → List Feeds.*

---

## 05 · Infrastructure Hardening

The platform underneath MISP. Most of this is already provisioned by the stack — the job
here is to understand it and close the remaining gaps for a real production account.

- **TLS everywhere, plus a WAF** — `WIRED` `CONFIGURE`
  Encrypt client traffic and filter malicious requests before they reach the app.
  *How:* ALB terminates TLS with an ACM cert (wired). Add AWS WAF (or Cloudflare WAF) in
  front for rate-limiting and common-attack rules.

- **Lock down the Kubernetes API endpoint** — `WIRED` `CONFIGURE` `CRITICAL`
  The EKS public API defaults to open for convenience; in production it should not accept
  connections from the whole internet.
  *Set:* `api_allowed_cidrs` to your egress IP (or go private + bastion). Flipping
  `production = true` is where you'd pair this with the other HA/safety levers.

- **Default-deny network policies** — `WIRED`
  Limits lateral movement — a compromised pod can only reach what it's explicitly allowed
  to.
  *How:* `k8s/06-networkpolicy.yaml` provides default-deny + an allow-list; apply it *last*
  (`make netpol`) once the stack is confirmed healthy. Needs a policy-enforcing CNI.

- **Secrets via External Secrets, not manifests** — `WIRED`
  Keeps credentials out of Git and out of plain Kubernetes manifests; centralises rotation.
  *How:* External Secrets Operator syncs from AWS Secrets Manager via a scoped IRSA role —
  no secrets in the repo. Rotate the DB password periodically.

- **Least-privilege cloud IAM** — `WIRED` `CONFIGURE`
  Pods should hold only the permissions they need; long-lived static keys are a standing
  liability.
  *How:* IRSA roles scope External Secrets and the EBS CSI driver. Known gap: MISP's S3
  attachments use a scoped IAM *user* key — migrate to an IRSA role on the `misp` service
  account when your build supports the default credential chain.

- **Isolate the cache tier** — `WIRED` `CONFIGURE`
  MISP-core has no Redis TLS support, so the ElastiCache endpoint runs without transit
  encryption — network isolation is the compensating control.
  *How:* Redis lives in private subnets, reachable only from the node security group, and
  the network policy scopes pod access. For stricter prod, front it with an `stunnel`
  sidecar.

---

## 06 · High Availability & Scaling

A production instance survives an AZ failure and a traffic spike. In this stack most of it
is a single toggle — but understand what it flips.

- **Flip the production toggle** — `WIRED` `CONFIGURE`
  Lab defaults trade resilience for cost. Production needs the opposite — and you want that
  as one deliberate switch, not a dozen manual edits.
  *Set:* `production = true` raises NAT-per-AZ, Multi-AZ RDS, a 2-node Redis with failover,
  larger instance classes, deletion protection, and a final snapshot.

- **Multi-AZ database** — `WIRED`
  The database is the one component you can't just recreate. Multi-AZ gives you automatic
  failover to a standby.
  *How:* Driven by the toggle (`db_multi_az`); overridable independently if you want HA DB
  but lab-sized everything else.

- **Scale the web tier safely** — `WIRED` `CONFIGURE`
  nginx is stateless and already runs 2 replicas; the php-fpm tier holds sessions, so
  scaling it needs shared session handling.
  *How:* Pinned crypto material makes replicas agree; enable ALB *sticky sessions* (or
  Redis/DB-backed sessions) before scaling `deploy/misp` past 1.

- **Keep scheduled tasks single-owner** — `CONFIGURE`
  Scheduled pulls/pushes (`CRON_PULLALL`/`CRON_PUSHALL`) must not double-fire across
  replicas, or you duplicate syncs and waste partner bandwidth.
  *How:* Pin the scheduled-task owner to one pod, or run a dedicated single-replica worker
  deployment for cron.

- **Provision worker capacity** — `CONFIGURE`
  Background workers process correlation, feeds, enrichment, and email. Under-provisioned
  queues silently back up and intel goes stale.
  *How:* Watch queue depth (*Administration → Jobs / Workers*), scale workers to match, and
  consider an HPA on CPU/memory.

---

## 07 · Backups & Recovery

Assume something will be deleted, corrupted, or ransomed. Backups only count if you've
restored from them.

- **Automated database backups** — `WIRED`
  The database is the heart of the instance — events, attributes, correlations, users.
  *How:* RDS automated snapshots run with 7-day retention. In production the toggle also
  enables a final snapshot on teardown and deletion protection.

- **Versioned, replicated attachments** — `WIRED` `CONFIGURE`
  Malware samples and attachments live in S3, not the DB — they need their own protection
  against deletion and corruption.
  *How:* The attachments bucket has versioning + KMS encryption + public-access block. For
  prod, add cross-region replication.

- **Back up crypto material separately** — `CONFIGURE` `CRITICAL`
  A perfect DB backup is useless if you've lost the `ENCRYPTION_KEY`/`SECURITY_SALT`/GPG key
  that decrypt and sign its contents.
  *How:* Keep an off-site, access-controlled copy of the Secrets Manager crypto material
  alongside — not inside — your data backups.

- **Test restores & define RTO/RPO** — `CONFIGURE`
  An untested backup is a hope, not a plan. Know how long recovery takes and how much data
  you can lose.
  *How:* Rehearse a rebuild (`make up` + restore snapshot + re-inject secrets), time it, and
  write the runbook.

- **Back up configuration** — `CONFIGURE`
  Server settings, feed definitions, taxonomies, and sharing groups are effort to rebuild by
  hand.
  *How:* Export server settings and feed/sync config periodically; keep the Terraform state
  backed up in remote state (S3 backend).

---

## 08 · Monitoring & Auditing

You can't defend or operate what you can't see. Audit trails also make MISP itself a source
for your SIEM.

- **Turn on MISP audit logging** — `CONFIGURE`
  Attribution and incident response need to know who did what, from where.
  *Set:* `MISP.log_client_ip`, `MISP.log_auth`, `MISP.log_user_ips`, and
  `Security.log_each_individual_auth_failure` — all `true`.

- **Ship logs off the cluster** — `CONFIGURE`
  Logs on an ephemeral pod vanish with it. Centralised logging survives restarts and enables
  detection.
  *How:* Forward container + audit logs to CloudWatch / Elastic / your SIEM. (This is the
  natural hand-off to a "MISP → SIEM" episode.)

- **Monitor workers, Redis & DB health** — `CONFIGURE`
  A stalled worker queue looks fine from the UI while intel quietly stops processing.
  *How:* Keep the *Administration → Diagnostics* page green; alert on failed jobs, queue
  backlog, and dead workers.

- **Alert on the failure modes that bite** — `CONFIGURE`
  The failures that take MISP down are predictable: disk full, cert expiry, DB connections,
  pod crash-loops.
  *How:* Set CloudWatch alarms on RDS storage/CPU, node/pod health, and certificate expiry
  (ACM auto-renews, but DNS validation must stay valid).

- **Watch data growth & correlation load** — `CONFIGURE`
  MISP is read-heavy on correlation; unbounded growth degrades performance and cost over
  months, not days.
  *How:* Trend DB size and query latency; tune the correlation engine and right-size
  instances as the dataset grows.

---

## 09 · Maintenance & Lifecycle

Production is a habit, not a one-time deploy. These keep the instance secure and accurate
over time.

- **Patch MISP on a schedule** — `CONFIGURE` `CRITICAL`
  MISP ships security fixes; running an old core is a known-vulnerability risk. Test upgrades
  and DB migrations in non-prod first.
  *How:* Bump `CORE_TAG`/`MODULES_TAG` deliberately (the Makefile echoes the resolved tags so
  you never deploy the wrong version by accident), stage the migration, then roll.

- **Pin image digests & scan** — `CONFIGURE`
  Tags can move; a digest can't. Scanning catches known CVEs in the image before it runs.
  *How:* Pin `misp-core`/`misp-modules` by SHA for reproducible deploys, and scan images in
  CI or via ECR pull-through.

- **Keep intelligence content current** — `CONFIGURE`
  Warninglists, noticelists, taxonomies, galaxies, and object templates evolve; stale content
  means false positives and missed context.
  *How:* Enable scheduled auto-updates (needs `MISP.background_jobs = true`, which the stack
  runs) and confirm they run.

- **Rotate credentials & review access** — `CONFIGURE`
  Keys and accounts accumulate. Periodic rotation and review shrink the standing blast radius.
  *How:* Rotate API keys and the DB password on a cadence; review users, roles, and sync
  connections quarterly and disable dormant accounts.

- **Track certificate & DNS validity** — `CONFIGURE`
  An expired cert or broken DNS takes the whole instance offline for every user and every
  partner sync at once.
  *How:* Ensure the ACM cert's DNS validation record stays in place so auto-renewal succeeds;
  monitor expiry as a safety net.

---

*Grounded in the `misp-production` EKS stack — Terraform + Kubernetes, RDS MariaDB,
ElastiCache Redis, S3 attachments, ALB + ACM, and External Secrets. "Wired" items are
provisioned by that stack; "Configure" items are yours to set in MISP or as infra levers.*
