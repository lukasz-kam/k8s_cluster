#!/bin/bash
set -e

CLUSTER_USER="$1"
NAMESPACE="default"
KUBECONFIG_FILE="/tmp/kubeconfig-$CLUSTER_USER.yaml"

kubectl delete clusterrolebinding "${CLUSTER_USER}-binding" --ignore-not-found
kubectl delete serviceaccount "$CLUSTER_USER" -n "$NAMESPACE" --ignore-not-found
kubectl create serviceaccount "$CLUSTER_USER" -n "$NAMESPACE" || true

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: full-readonly
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get","list","watch"]
EOF

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $CLUSTER_USER-binding
subjects:
- kind: ServiceAccount
  name: $CLUSTER_USER
  namespace: $NAMESPACE
roleRef:
  kind: ClusterRole
  name: full-readonly
  apiGroup: rbac.authorization.k8s.io
EOF

TOKEN=$(kubectl create token "$CLUSTER_USER" -n "$NAMESPACE")

CLUSTER_NAME=$(kubectl config view -o jsonpath='{.clusters[0].name}')
SERVER=$(kubectl config view -o jsonpath="{.clusters[0].cluster.server}")

kubectl config set-cluster "$CLUSTER_NAME" \
  --server="$SERVER" \
  --certificate-authority=/var/lib/rancher/k3s/server/tls/server-ca.crt \
  --embed-certs=true \
  --kubeconfig="$KUBECONFIG_FILE"

kubectl config set-credentials "$CLUSTER_USER" \
  --token="${TOKEN}" \
  --kubeconfig="$KUBECONFIG_FILE"

kubectl config set-context "${CLUSTER_USER}-context" \
  --cluster="$CLUSTER_NAME" \
  --user="$CLUSTER_USER" \
  --namespace="$NAMESPACE" \
  --kubeconfig="$KUBECONFIG_FILE"

kubectl config use-context "${CLUSTER_USER}-context" --kubeconfig="$KUBECONFIG_FILE"