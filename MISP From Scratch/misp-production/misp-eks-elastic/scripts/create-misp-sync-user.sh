#!/usr/bin/env bash
# create-misp-sync-user.sh
# Creates a least-privilege READ-ONLY MISP user for Elastic to pull IOCs, and prints
# its auth key. Runs the MISP cake console inside the running php-fpm pod.
#
# Usage:  NAMESPACE=misp ./create-misp-sync-user.sh elastic@kravensecurity.com
set -euo pipefail

NAMESPACE="${NAMESPACE:-misp}"
EMAIL="${1:-elastic@kravensecurity.com}"

# Role IDs in a default MISP install (VERIFY in your instance under Administration →
# Roles): 1=admin, 2=org admin, 3=user, 4=publisher, 5=sync user, 6=read only.
# We want read-only for a pull-only integration.
ROLE_ID="${ROLE_ID:-6}"
ORG_ID="${ORG_ID:-1}"

POD="$(kubectl -n "$NAMESPACE" get pod -l app=misp -o jsonpath='{.items[0].metadata.name}')"
echo "Using MISP pod: $POD (container: misp)"

echo "Creating user $EMAIL (role $ROLE_ID, org $ORG_ID)..."
kubectl -n "$NAMESPACE" exec "$POD" -c misp -- \
  /var/www/MISP/app/Console/cake user create "$EMAIL" "$ROLE_ID" "$ORG_ID" || true

echo "Generating a fresh auth key..."
kubectl -n "$NAMESPACE" exec "$POD" -c misp -- \
  /var/www/MISP/app/Console/cake user change_authkey "$EMAIL"

echo
echo ">>> Copy the auth key printed above into:"
echo "    - elastic/filebeat-collector.yaml  (MISP_API_TOKEN), or"
echo "    - the MISP integration in Kibana (Method 1)."
echo ">>> Scope what Elastic can pull by tagging/publishing events and using the"
echo "    integration's type/tag filters."
