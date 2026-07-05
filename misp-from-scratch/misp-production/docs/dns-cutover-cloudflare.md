# DNS Cutover to the ALB (Cloudflare)

Once Phase 2 is applied and the Ingress has provisioned an ALB, point your MISP
hostname at it. This assumes your domain is on Cloudflare — if you issued the ACM
cert via [`acm-certificate-setup.md`](acm-certificate-setup.md), this is the same
zone.

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
   * **Name:** the subdomain part of `MISP_HOSTNAME` (e.g. `misp.lab` for
     `misp.lab.kravensecurity.com` — Cloudflare appends the zone automatically).
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
HTTP, which — combined with `DISABLE_SSL_REDIRECT=true` on nginx — can reintroduce
the redirect-loop/CSRF problems this stack already works around.

---

## Step 4: Verify

Propagation through Cloudflare is usually near-instant (no waiting like ACM DNS
validation). Confirm:

```bash
dig +short "$MISP_HOSTNAME"
curl -sI "https://$MISP_HOSTNAME" | head -5
```

Then browse to `https://$MISP_HOSTNAME` — the cert should be valid and you should
reach the MISP login page. Continue with Phase 3's login step from there.
