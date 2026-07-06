# Issuing + DNS-validating the ACM certificate (Cloudflare)

The ALB terminates TLS with a public ACM certificate for `misp_hostname`. Issue and
validate it **off-air** — DNS validation is slow and you don't want to wait for it on
a live stream. This walks through requesting the cert in ACM and adding the
validation record in Cloudflare. Route 53 users: the flow is the same, you just add
the validation CNAME in your hosted zone instead (ACM can even create it for you).

> **ACM certs can't be downloaded.** Unlike Let's Encrypt, an ACM cert never lands on
> disk as `.crt`/`.key` — it only attaches to AWS-managed resources (ALB, CloudFront,
> API Gateway). This stack puts an ALB in front of MISP, so ACM is the right fit. If
> you ever run MISP on a bare EC2 box with no load balancer, use Let's Encrypt
> (Certbot) instead.

> **Region matters.** An ALB-attached cert **must** be issued in the same region as
> the cluster/ALB (`var.region`, default `eu-west-1`). Only CloudFront requires the
> cert in `us-east-1`. This stack uses an ALB, so issue the cert in your cluster
> region.

> **Choosing the hostname.** If you also proxy real traffic through Cloudflare (orange
> cloud) — see [`dns-cutover-cloudflare.md`](dns-cutover-cloudflare.md) — pick a
> **single-level** hostname (e.g. `misp-lab.example.com`), not a nested one like
> `misp.lab.example.com`. That's about Cloudflare's edge-cert coverage, not ACM, but
> it's easiest to get right by deciding the hostname once, up front.

---

## 1. Request the certificate

In the ACM console (in your cluster region), **Request a certificate → public
certificate**, then:

- **Fully qualified domain name** — the hostname MISP will serve on (e.g.
  `misp-lab.example.com`), or a wildcard (`*.example.com`) to cover multiple services.
- **Validation method** — DNS validation.
- **Key algorithm** — `RSA 2048` (widely compatible).

Request it, then note the certificate ARN — it goes into `acm_certificate_arn` in
`terraform.tfvars`.

---

## 2. Grab the validation record

Open the pending certificate. Under **Domains**, copy the **CNAME name** and **CNAME
value** — you'll add them to Cloudflare next.

---

## 3. Add the CNAME in Cloudflare

**DNS → Records → Add record:**

- **Type** — `CNAME`
- **Name** — the ACM **CNAME name** (Cloudflare strips your root domain automatically
  if you paste the full string).
- **Target** — the ACM **CNAME value** (e.g. `_x3.acm-validations.aws.`).
- **Proxy status** — **DNS only (grey cloud)**. This is the step people miss: if it's
  proxied (orange cloud), AWS's validators hit Cloudflare's edge instead of reading
  the raw record, and the cert sits in *Pending validation* forever.

---

## 4. Wait for issuance

ACM polls for the record and usually flips **Pending validation → Issued** within
2–10 minutes. Refresh the ACM console to confirm.

---

## Troubleshooting — CAA record blocks validation

A CAA record is an allow-list of which Certificate Authorities may issue certs for
your domain. If validation stalls with a CAA error, an existing CAA record (or a
Cloudflare default) is restricting issuance to another CA, and Amazon respects it and
stops. Fix: add Amazon to the list.

**Cloudflare → DNS → Records → Add record:**

- **Type** — `CAA`
- **Name** — `@` (root domain + all subdomains)
- **Tag** — *Only allow specific CAs to issue certificates (issue)*
- **Value / CA domain name** — `amazon.com`
- **TTL** — Auto

Existing CAA records you use elsewhere can stay — this adds AWS alongside them. ACM
retries on its own, but to skip the wait: delete the pending cert and request a fresh
one. With `amazon.com` now allow-listed, it validates within minutes.

---

## Attaching real traffic (optional)

Once the cert is **Issued**, Terraform attaches it to the ALB's HTTPS listener via
`acm_certificate_arn`. When you later point `misp_hostname` at the ALB (see
[`dns-cutover-cloudflare.md`](dns-cutover-cloudflare.md) or
[`dns-cutover-route53.md`](dns-cutover-route53.md)):

- You can keep that record **proxied (orange cloud)** in Cloudflare for DDoS/WAF
  cover.
- Set Cloudflare's **SSL/TLS mode** to **Full (strict)** so Cloudflare→ALB stays
  encrypted against the ACM cert — never *Flexible*.
