#!/bin/bash
set -euo pipefail

PARAM_NAME="/k3s/kubeconfig"
MAX_RETRIES=10
RETRY_INTERVAL=5
i=1

while [ $i -le $MAX_RETRIES ]; do
  KUBECONFIG_CONTENT=$(aws ssm get-parameter \
    --name "$PARAM_NAME" \
    --with-decryption \
    --query "Parameter.Value" \
    --output text 2>/dev/null || true)

  if [ -n "$KUBECONFIG_CONTENT" ] && [ "$KUBECONFIG_CONTENT" != "None" ]; then
    echo "Kubeconfig found!"
    echo "$KUBECONFIG_CONTENT" > kubeconfig.yaml
    echo "KUBECONFIG=$(pwd)/kubeconfig.yaml" >> "$GITHUB_ENV"
    exit 0
  fi

  echo "Kubeconfig not ready yet, retrying in $RETRY_INTERVAL seconds..."
  sleep $RETRY_INTERVAL
  i=$((i+1))
done

echo "Error: Kubeconfig still not available in SSM after $((MAX_RETRIES*RETRY_INTERVAL)) seconds."
exit 1