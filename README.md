# K3s Cluster Bootstrap

A production-ready Kubernetes cluster setup using K3s, focusing on security and GitOps practices.

## Prerequisites

```shell
# System dependencies
sudo apt install zfsutils-linux nfs-kernel-server cifs-utils open-iscsi
sudo apt install --reinstall zfs-dkms

# Install 1Password CLI
# Follow instructions at: https://1password.com/downloads/command-line/

# Fix kubeconfig permissions (after k3s install)
chmod 600 ~/.kube/config
```

## 1. Initial Cluster Setup

```shell
export SETUP_NODEIP=192.168.10.11
export SETUP_CLUSTERTOKEN=randomtokensecret123456789567556556

# Install K3s
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.31.2+k3s1" \
  INSTALL_K3S_EXEC="--node-ip $SETUP_NODEIP \
  --disable=flannel,local-storage,metrics-server,servicelb,traefik \
  --flannel-backend='none' \
  --disable-network-policy \
  --disable-cloud-controller \
  --disable-kube-proxy" \
  K3S_TOKEN=$SETUP_CLUSTERTOKEN \
  K3S_KUBECONFIG_MODE=644 sh -s -

# Setup kubeconfig
mkdir -p $HOME/.kube
sudo cp -i /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
echo "export KUBECONFIG=$HOME/.kube/config" >> $HOME/.bashrc
source $HOME/.bashrc
```

# Install Cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz

# Install Cilium
API_SERVER_IP=192.168.10.11
API_SERVER_PORT=6443
cilium install \
  --version 1.16.4 \
  --set k8sServiceHost=${API_SERVER_IP} \
  --set k8sServicePort=${API_SERVER_PORT} \
  --set kubeProxyReplacement=true \
  --helm-set=operator.replicas=1

# Verify Cilium installation
cilium status

## 2. Secrets Setup (Required before ArgoCD)

```shell
# Generate Connect credentials
op connect server create  # Creates 1password-credentials.json

# Store token for reuse
export CONNECT_TOKEN="your-1password-connect-token"

# Create required secrets
kubectl create namespace 1passwordconnect

#BASE64 the json first!!!
kubectl create secret generic 1password-credentials \
  --from-file=1password-credentials.json=/path/to/1password-credentials.json \
  --namespace 1passwordconnect


kubectl create secret generic 1password-operator-token \
  --from-literal=token=$CONNECT_TOKEN \
  --namespace 1passwordconnect

# Create external-secrets token (same token)
kubectl create namespace external-secrets
kubectl create secret generic 1passwordconnect \
  --from-literal=token=$CONNECT_TOKEN \
  --namespace external-secrets
```

## 3. Required 1Password Vault Items

Create these items in your 1Password vault before proceeding:

1. `cert-manager-proxmox`:
   - Field: `token` (Cloudflare API token)

2. `cloudflared-proxmox`:
   - Field: `tunnel-credentials` (JSON format)
   ```json
   {
     "AccountTag": "your-account-tag",
     "TunnelSecret": "your-tunnel-secret",
     "TunnelID": "your-tunnel-id"
   }
   ```

3. `external-secrets`:
   - Field: `token` (same as $CONNECT_TOKEN)

## 4. Apply Infrastructure


# Install Gateway API CRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/experimental-install.yaml

# Install Argo CD
kubectl kustomize --enable-helm infra/controllers/argocd | kubectl apply -f -

# Get initial admin password (if needed)
kubectl -n argocd get secret argocd-initial-admin-secret -ojsonpath="{.data.password}" |

```shell
# Apply all infrastructure components via ArgoCD
kubectl apply -k infra/
```

kubectl apply -k sets

# Apply full infrastructure
kubectl kustomize infra | kubectl apply -f -

## 5. Verify Setup

```shell
# Check 1Password Connect
kubectl get pods -n 1passwordconnect
kubectl get secret 1password-credentials -n 1passwordconnect

# Check External Secrets
kubectl get externalsecret -A
kubectl get clustersecretstore 1password -n external-secrets

# Check specific secrets
kubectl get secret cloudflare-api-token -n cert-manager
kubectl get secret tunnel-credentials -n cloudflared

# Check for errors
kubectl logs -n 1passwordconnect -l app=onepassword-connect
```

# Components Status

- [x] Cilium
- [ ] Hubble
- [x] Argo CD
- [x] Proxmox CSI Plugin
- [x] Cert-manager
- [x] Gateway API
- [ ] CNPG (Cloud Native PostgreSQL)
- [ ] Authentication (Keycloak/Authentik)
- [ ] Sealed Secrets
- [ ] Cloudflared Tunnel

# Troubleshooting

If secrets aren't syncing:
1. Verify 1Password Connect is running
2. Check vault items exist with correct field names
3. Check External Secrets operator logs
4. Verify ClusterSecretStore is ready