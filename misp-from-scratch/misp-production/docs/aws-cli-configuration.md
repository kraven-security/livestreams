# Configuring the AWS CLI for Terraform

This assumes the AWS CLI is already installed (see
[`tool-installation.md`](tool-installation.md)). This page covers getting it
**authenticated** so `terraform init/plan/apply` in `terraform/` — and later
`kubectl`/`helm`, which reuse the same credentials via `aws eks get-token` — can
talk to your account.

The Terraform here provisions EKS, RDS, ElastiCache, VPC networking, IAM
roles/policies/users, Secrets Manager secrets, S3, and an ALB — i.e. it needs
**admin-ish** permissions, not a narrowly scoped role. Don't spend time trying to
hand-craft a minimal IAM policy for this stack; use an account/role you already
trust with broad access (this is explicitly a lab/livestream runbook, not a
least-privilege production pattern).

---

## Option A — IAM user with access keys (fastest for a lab)

1. In the **IAM console**, create (or reuse) an IAM user with programmatic access
   and attach `AdministratorAccess` (or an equivalent broad policy covering EC2,
   EKS, RDS, ElastiCache, S3, IAM, Secrets Manager, ELB).
2. Generate an **access key** for that user (IAM → Users → your user → Security
   credentials → Create access key).
3. Configure the CLI with a named profile instead of the default profile — this
   keeps it separate from any other AWS work on the same machine:
   ```bash
   aws configure --profile misp-eks
   # AWS Access Key ID:     AKIA...
   # AWS Secret Access Key: ...
   # Default region name:   eu-west-1      # match terraform.tfvars `region`
   # Default output format: json
   ```
4. Point every terminal you use for this runbook at that profile:
   ```bash
   export AWS_PROFILE=misp-eks
   ```

---

## Option B — IAM Identity Center / SSO (recommended if your org has it)

Avoids long-lived access keys sitting on disk.

```bash
aws configure sso --profile misp-eks
# SSO session name, SSO start URL, SSO region — from your org's IAM Identity Center
# Select the account + permission set (needs the same broad access as above)
```

Log in (session expires periodically — re-run when the CLI complains):
```bash
aws sso login --profile misp-eks
export AWS_PROFILE=misp-eks
```

---

## Matching the region

The `region` in [`terraform/terraform.tfvars`](../misp-eks/terraform/terraform.tfvars)
(also used for the ACM cert — see
[`acm-certificate-setup.md`](acm-certificate-setup.md)) must match the region you
configured for the profile, since `provider "aws"` in `versions.tf` takes its
region from `var.region`, not from the CLI default. If they diverge you'll see
EKS/VPC resources created in the wrong region or `NoCredentialProviders`-style
errors when a data source assumes the CLI default region.

---

## Verify before running Terraform

```bash
aws sts get-caller-identity --profile misp-eks
# {
#   "UserId": "...",
#   "Account": "123456789012",
#   "Arn": "arn:aws:iam::123456789012:user/you"
# }
```

If that returns an identity, `terraform init` / `plan` / `apply` in `terraform/`
will pick up the same credentials automatically via the standard AWS SDK
credential chain (env vars → `AWS_PROFILE` → `~/.aws/credentials` → instance/
container role). No `profile` argument needs to be added to `provider "aws"` in
this repo.

---

## Credentials also drive kubectl/helm later

Phase 2's `kubectl`/`helm` calls authenticate to the EKS cluster via `aws eks
get-token` (wired into `provider "kubernetes"` / `provider "helm"` in
`versions.tf`, and into `configure_kubectl` output for your shell). That means
whichever `AWS_PROFILE`/SSO session was active during `terraform apply` must
still be valid — and exported in any new terminal — when you run `kubectl` or
`helm` against the cluster afterward, or those commands will fail auth even
though Terraform succeeded.

---

## Don't commit credentials

Never put access keys in `terraform.tfvars` or any `.tf` file — this stack
authenticates purely through the CLI's credential chain, so there's no reason to.
`terraform.tfvars` is already git-ignored (see `.gitignore`); keep it that way,
and keep `~/.aws/credentials` out of version control entirely.
