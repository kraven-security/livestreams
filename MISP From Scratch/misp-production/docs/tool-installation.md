# Installing the Required Tools

This runbook assumes recent versions of `awscli` v2, `terraform` ≥ 1.6, `kubectl`,
`helm`, `envsubst` (from `gettext`), and `jq` are already installed and on your
`PATH`. This page walks through installing each one on macOS, Debian/Ubuntu, and
RHEL/Amazon Linux, plus how to verify the install.

> Run the **verify** command under each tool after installing — several later
> phases (`terraform apply`, `kubectl apply`, `envsubst < ...`) fail with unhelpful
> errors if one of these is missing or too old.

---

## AWS CLI v2

Used to read Terraform-created secrets (`aws secretsmanager get-secret-value`),
inspect S3 attachments, and check service quotas.

**macOS:**
```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
```
Or via Homebrew: `brew install awscli`

**Debian/Ubuntu:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**RHEL/Amazon Linux:** same as Debian/Ubuntu (the installer is a generic Linux
binary, not a package-manager artifact).

**Configure credentials** (needed before any `terraform apply` or `aws` command):
```bash
aws configure
# or: export AWS_PROFILE=your-profile
```

**Verify:**
```bash
aws --version        # aws-cli/2.x.x
aws sts get-caller-identity
```

---

## Terraform (≥ 1.6)

Provisions the EKS foundation in Phase 1 (VPC, EKS, RDS, ElastiCache, S3, IAM,
Secrets Manager).

**macOS (Homebrew):**
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

**Debian/Ubuntu:**
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

**RHEL/Amazon Linux:**
```bash
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo yum install terraform
```

**Verify:**
```bash
terraform version     # Terraform v1.6.x or newer
```

---

## kubectl

Talks to the EKS cluster once `configure_kubectl` is applied in Phase 1, and
applies/watches the manifests in Phase 2.

**macOS (Homebrew):**
```bash
brew install kubectl
```

**Debian/Ubuntu:**
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

**RHEL/Amazon Linux:**
```bash
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
EOF
sudo yum install -y kubectl
```

Match the kubectl minor version to the EKS cluster's Kubernetes version where
possible (±1 minor version is supported).

**Verify:**
```bash
kubectl version --client
```

---

## Helm

The Terraform in Phase 1 installs the AWS Load Balancer Controller and External
Secrets Operator via Helm; having the `helm` CLI locally is useful for inspecting
or debugging those releases (`helm list -A`, `helm get values ...`).

**macOS (Homebrew):**
```bash
brew install helm
```

**Debian/Ubuntu/RHEL (official script, works on both):**
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

**Verify:**
```bash
helm version
```

---

## envsubst (gettext)

Renders the `${PLACEHOLDER}` tokens in the `k8s/*.yaml` manifests before they're
applied (`render()` helper in Phase 2).

**macOS (Homebrew):**
```bash
brew install gettext
brew link --force gettext
```

**Debian/Ubuntu:**
```bash
sudo apt update && sudo apt install gettext-base
```

**RHEL/Amazon Linux:**
```bash
sudo yum install -y gettext
```

**Verify:**
```bash
envsubst --version
echo 'hello ${NAME}' | NAME=world envsubst
```

---

## jq

Parses JSON output from `aws secretsmanager get-secret-value`, Terraform outputs,
and the API smoke test in Phase 5.

**macOS (Homebrew):**
```bash
brew install jq
```

**Debian/Ubuntu:**
```bash
sudo apt update && sudo apt install jq
```

**RHEL/Amazon Linux:**
```bash
sudo yum install -y jq
```

**Verify:**
```bash
jq --version
echo '{"a":1}' | jq .a
```

---

## Quick check for all tools

Run this once everything above is installed to confirm the whole toolchain is on
`PATH` before starting Phase 1:

```bash
for bin in aws terraform kubectl helm envsubst jq; do
  command -v "$bin" >/dev/null 2>&1 \
    && echo "OK   $bin -> $(command -v "$bin")" \
    || echo "MISSING $bin"
done
```
