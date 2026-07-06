# DNS Cutover to the ALB (Cloudflare)

Once Phase 2 is applied and the Ingress has provisioned an ALB, point your MISP
hostname at it. This assumes your domain is on Cloudflare — if you issued the ACM
cert via [`acm-certificate-setup.md`](acm-certificate-setup.md), this is the same
zone.

> **Use a single-level hostname** (e.g. `misp.kravensecurity.com` or
> `misp-lab.kravensecurity.com`) — **not** a nested one like
> `misp.lab.kravensecurity.com`. Cloudflare's free Universal SSL edge certificate
> only covers `example.com` + `*.example.com` (one wildcard level). A two-level
> hostname has no matching edge cert, so Cloudflare's edge fails the TLS handshake
> before traffic ever reaches AWS — browsers report this as
> `SSL_ERROR_NO_CYPHER_OVERLAP` (Firefox) or a generic handshake-failure error
> (Chrome). Confirmed directly against Cloudflare's edge IP: connecting with SNI =
> a two-level hostname gets an immediate `handshake_failure` alert because
> Cloudflare has nothing to present for it. Fix is either a single-level hostname
> (this doc) or turning on **SSL/TLS → Edge Certificates → Total TLS** in
> Cloudflare, which issues a dedicated cert for deeper subdomains too.

> **Do this again after every `make down` + `make up` cycle.** The ALB gets a
> brand-new hostname (a fresh random suffix) every time the Ingress is recreated
> from scratch — the old CNAME target stops resolving the moment the previous
> ALB is destroyed. If the site suddenly returns a Cloudflare **530** (origin
> unreachable) after a fresh deploy, this is almost always why: the CNAME is
> still pointing at the old, now-gone ALB. Get the new hostname (Step 1) and
> update the *existing* record's target (Step 2) — no need to delete/recreate
> the record itself.

---

## Step 1: Get the ALB hostname

```bash
kubectl -n "$NAMESPACE" get ingress misp \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

This returns something like
`k8s-misp-misp-xxxxxxxxxx-xxxxxxxxxx.eu-west-1.elb.amazonaws.com`.

---

## Step 2: Add the CNAME record in Cloudflare

1. Log into the **Cloudflare Dashboard** and select your domain (e.g.
   `kravensecurity.com`).
2. Go to **DNS** → **Records**.
3. Click **Add record** and configure it as follows:
   * **Type:** `CNAME`
   * **Name:** the subdomain part of `MISP_HOSTNAME` (e.g. `misp-lab` for
     `misp-lab.kravensecurity.com` — Cloudflare appends the zone automatically).
     Keep this single-level — see the warning above.
   * **Target:** the ALB hostname from Step 1.
   * **Proxy status:** 🟠 **Proxied (Orange Cloud)**. Unlike the ACM DNS-validation
     record (which must be DNS-only/grey cloud), this is your real traffic record —
     proxying through Cloudflare is fine and gives you their DDoS/WAF protection in
     front of the ALB.
4. Click **Save**.

---

## Step 3: Set the SSL/TLS encryption mode

1. Go to **SSL/TLS** → **Overview** for the zone.
2. Set the mode to **Full** or **Full (strict)** — not **Flexible**.

The ALB already terminates TLS with your ACM cert, so Cloudflare needs to connect
to it over HTTPS. "Flexible" mode would have Cloudflare talk to the ALB over plain
HTTP, which can reintroduce the redirect-loop/CSRF problems this stack already
works around (nginx trusts the ALB's forwarded scheme/IP — see the main
README's "Behind-ALB correctness" section — and that trust assumes the ALB is
genuinely the one talking to it over HTTPS).

---

## Step 4: Verify

Propagation through Cloudflare is usually near-instant (no waiting like ACM DNS
validation). Confirm:

```bash
dig +short "$MISP_HOSTNAME"                       # should return Cloudflare IPs (104.x/172.x/188.x), not an AWS IP
curl -vI --connect-timeout 10 "https://$MISP_HOSTNAME" 2>&1 | grep -i "subjectAltName\|handshake"
```

If you get a TLS handshake failure here (curl: `SSL routines::ssl/tls alert
handshake failure`, Firefox: `SSL_ERROR_NO_CYPHER_OVERLAP`), it's almost always
the two-level-hostname edge-cert gap described above, not an AWS/ALB problem —
confirm by checking `subjectAltName` in the curl output against `$MISP_HOSTNAME`.

Then browse to `https://$MISP_HOSTNAME` — the cert should be valid and you should
reach the MISP login page. Continue with Phase 3's login step from there.
