#!/bin/bash

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)

aws ssm delete-parameter --name "/k3s/kubeconfig" || true

if [ -z "$PRIVATE_IP" ] || [ -z "$PUBLIC_IP" ]; then
  echo "Failed to retrieve IP addresses from metadata. Exiting." >&2
  exit 1
fi

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644 --disable=traefik --tls-san $PUBLIC_IP --tls-san $PRIVATE_IP" sh -

TOKEN_FILE="/var/lib/rancher/k3s/server/node-token"
while [ ! -s "$TOKEN_FILE" ]; do
  sleep 2
done
K3S_TOKEN=$(cat $TOKEN_FILE)

KUBECONFIG_FILE="/etc/rancher/k3s/k3s.yaml"
while [ ! -s "$KUBECONFIG_FILE" ]; do
  sleep 2
done
KUBE_SECRET=$(cat $KUBECONFIG_FILE)

aws ssm put-parameter \
  --name "/k3s/kubeconfig" \
  --value "$KUBE_SECRET" \
  --type SecureString \
  --overwrite \
  --region ${AWS_REGION}

aws ssm put-parameter \
  --name "/k3s/token" \
  --value "$K3S_TOKEN" \
  --type SecureString \
  --overwrite \
  --region ${AWS_REGION}

echo "K3s installation complete."

echo "Installing traefik..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
helm repo add traefik https://traefik.github.io/charts
helm repo update

cat <<EOF >/tmp/traefik-values.yaml
service:
  enabled: false
EOF

cat <<EOF >/tmp/traefik-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: traefik
  namespace: kube-system
spec:
  type: NodePort
  selector:
    app.kubernetes.io/name: traefik
  ports:
    - name: http
      port: 80
      targetPort: 8000
      nodePort: 30080
EOF

export KUBECONFIG=$KUBECONFIG_FILE
helm upgrade --install traefik traefik/traefik -n kube-system -f /tmp/traefik-values.yaml
kubectl apply -f /tmp/traefik-svc.yaml