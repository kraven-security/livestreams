# Makefile
# Wraps this repo's README Phase 1 / Phase 2 / Teardown steps into single
# commands, so the "destroy between demo sessions" cost habit (see README's Cost
# warning) doesn't depend on remembering the exact sequence. This mirrors the
# README exactly, including holding NetworkPolicies until you've manually
# confirmed the stack is healthy (`make netpol` is a separate step, not part of
# `make up`) — a misconfigured NetworkPolicy looks identical to a broken
# deployment, so it's deliberately not automated into the same run.
#
# Requires AWS_PROFILE to already be exported (see docs/aws-cli-configuration.md).
# Override CORE_TAG/MODULES_TAG/NAMESPACE/VPC_CIDR on the command line if needed,
# e.g. `make up CORE_TAG=v2.5.42`.

.ONESHELL:
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

NAMESPACE   ?= misp
VPC_CIDR    ?= 10.42.0.0/16
CORE_TAG    ?= v2.5.30
MODULES_TAG ?= v3.0.4

.PHONY: up netpol down

up:
	test -n "$${AWS_PROFILE:-}" || { echo "AWS_PROFILE is not set — see docs/aws-cli-configuration.md" >&2; exit 1; }
	cd terraform
	terraform init
	terraform plan -out tfplan
	APPLY_FAILED=0
	terraform apply tfplan || APPLY_FAILED=1
	eval "$$(terraform output -raw configure_kubectl)"
	if [ "$$APPLY_FAILED" = "1" ]; then
	  echo "terraform apply failed — checking for a known startup race: on a fresh" >&2
	  echo "cluster, external-secrets (or another addon)'s Helm release can try to" >&2
	  echo "create a Service before the aws-load-balancer-controller's admission" >&2
	  echo "webhook is actually up, since that controller's own helm_release doesn't" >&2
	  echo "wait for its pods by default (see README Troubleshooting)." >&2
	  FAILED_RELEASES="$$(helm list -A --all -o json 2>/dev/null | jq -r '.[] | select(.status=="failed") | "\(.namespace) \(.name)"')"
	  if [ -z "$$FAILED_RELEASES" ]; then
	    echo "No failed Helm release found, so this isn't that known race — not" >&2
	    echo "retrying automatically. Investigate the error above and re-run make up." >&2
	    exit 1
	  fi
	  echo "Found failed release(s), which is consistent with the race. Clearing" >&2
	  echo "them and retrying once (by now the webhook should be up):" >&2
	  echo "$$FAILED_RELEASES" >&2
	  echo "$$FAILED_RELEASES" | while read -r ns name; do
	    [ -n "$$name" ] && helm -n "$$ns" uninstall "$$name"
	  done
	  terraform apply -auto-approve
	fi
	export REGION="$$(terraform output -raw region)"
	export NAMESPACE="$(NAMESPACE)"
	export MISP_HOSTNAME="$$(terraform output -raw misp_hostname)"
	export ACM_CERT_ARN="$$(terraform output -raw acm_certificate_arn)"
	export ESO_ROLE_ARN="$$(terraform output -raw eso_irsa_role_arn)"
	export VPC_CIDR="$(VPC_CIDR)"
	export CORE_TAG="$(CORE_TAG)"
	export MODULES_TAG="$(MODULES_TAG)"
	cd ../k8s
	render() { envsubst < "$$1" | kubectl apply -f - ; }
	render 00-namespace-rbac.yaml
	render 01-external-secrets.yaml
	kubectl -n "$$NAMESPACE" get externalsecret
	kubectl -n "$$NAMESPACE" get secret mysql-credentials instance-secrets
	render 02-services.yaml
	render 03-deployment-misp.yaml
	render 04-deployment-nginx.yaml
	render 05-ingress.yaml
	echo "Applied through Ingress. Watch rollout: kubectl -n $$NAMESPACE get pods -w"
	echo "Once healthy, lock it down with: make netpol NAMESPACE=$$NAMESPACE VPC_CIDR=$(VPC_CIDR)"

# Apply NetworkPolicies LAST, after you've confirmed login + a feed pull work —
# matches the README's Phase 4 guidance. Not part of `up` on purpose.
netpol:
	export NAMESPACE="$(NAMESPACE)"
	export VPC_CIDR="$(VPC_CIDR)"
	envsubst < k8s/06-networkpolicy.yaml | kubectl apply -f -
	echo "Re-test login + a feed pull afterwards to confirm nothing is wrongly blocked."

down:
	test -n "$${AWS_PROFILE:-}" || { echo "AWS_PROFILE is not set — see docs/aws-cli-configuration.md" >&2; exit 1; }
	export NAMESPACE="$(NAMESPACE)"
	kubectl delete -f <(envsubst < k8s/06-networkpolicy.yaml) || true
	kubectl delete namespace "$$NAMESPACE" || true
	cd terraform
	terraform destroy
