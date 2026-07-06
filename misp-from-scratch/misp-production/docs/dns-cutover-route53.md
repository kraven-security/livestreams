# DNS Cutover to the ALB (Route 53)

Once Phase 2 is applied and the Ingress has provisioned an ALB, point your MISP
hostname at it. This assumes `misp_hostname` sits in a **Route 53 hosted zone** you
control. (On Cloudflare instead? See
[`dns-cutover-cloudflare.md`](dns-cutover-cloudflare.md).)

Route 53 is simpler than the Cloudflare path: there's no edge proxy and no SSL-mode
setting — the ALB terminates TLS directly with your ACM cert, so DNS just has to
resolve the hostname to the ALB. Prefer an **alias A record** over a CNAME: it's free,
works at a zone apex, and tracks the ALB directly.

> **Re-do this after every `make down` + `make up` cycle.** The Ingress creates a
> brand-new ALB with a fresh hostname each time, so the old target stops resolving
> the moment the previous ALB is destroyed. If a fresh deploy suddenly 502s/times
> out, the alias is almost certainly still pointing at the old, now-gone ALB —
> re-select the new one (Step 2).

---

## Step 1: Get the ALB hostname

```bash
kubectl -n "$NAMESPACE" get ingress misp \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

This returns something like
`k8s-misp-misp-xxxxxxxxxx-xxxxxxxxxx.eu-west-1.elb.amazonaws.com`.

---

## Step 2: Create the alias record

**Console** — Route 53 → your hosted zone → **Create record**:

- **Record name** — the subdomain of `misp_hostname` (e.g. `misp-lab`).
- **Record type** — `A`.
- **Alias** — on.
- **Route traffic to** — *Alias to Application and Classic Load Balancer*, your
  cluster region, then the ALB from Step 1.
- **Routing policy** — Simple.

Save. (A plain `CNAME` to the ALB hostname also works for a non-apex host, but the
alias is preferred.)

**CLI** — if you'd rather script it, an alias needs the ALB's canonical hosted-zone
ID and DNS name:

```bash
ALB_DNS="$(kubectl -n "$NAMESPACE" get ingress misp \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
ALB_ZONE="$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='$ALB_DNS'].CanonicalHostedZoneId" --output text)"

aws route53 change-resource-record-sets --hosted-zone-id "$YOUR_ZONE_ID" \
  --change-batch "$(jq -n --arg name "$MISP_HOSTNAME" --arg dns "$ALB_DNS" --arg zone "$ALB_ZONE" '{
    Changes: [{
      Action: "UPSERT",
      ResourceRecordSet: {
        Name: $name, Type: "A",
        AliasTarget: { HostedZoneId: $zone, DNSName: $dns, EvaluateTargetHealth: true }
      }
    }]
  }')"
```

`UPSERT` means the same command updates the record in place after a redeploy — no
delete/recreate needed.

---

## Step 3: Verify

Route 53 propagation is usually near-instant. Confirm:

```bash
dig +short "$MISP_HOSTNAME"                       # should resolve to AWS ELB IPs
curl -vI --connect-timeout 10 "https://$MISP_HOSTNAME" 2>&1 | grep -i "subjectAltName\|handshake"
```

Then browse to `https://$MISP_HOSTNAME` — the ACM cert should be valid and you should
reach the MISP login page. Continue with Phase 3's login step from there.
