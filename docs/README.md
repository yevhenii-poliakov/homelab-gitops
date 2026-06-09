# homelab-gitops

I built this to get hands-on with GitOps and ArgoCD — tools I want to work with professionally, not just claim on a CV. Terraform was a secondary goal: I use it at work but wanted to own something end-to-end myself, from VM provisioning to application deployment.

One thing I learned the hard way: ArgoCD's `selfHeal` reverts any manual `kubectl patch` within seconds. Annoying at first, but it forced me to understand that the Git repo is the only source of truth — which is exactly the point of GitOps.

## What this demonstrates

| CV Claim | Proof in this repo |
|---|---|
| Kubernetes | k3s cluster on Hetzner Cloud, managed via GitOps |
| Terraform | Provisions Hetzner VM, firewall rules, SSH key references |
| Ansible | Bootstraps k3s, configures UFW, fetches kubeconfig |
| Helm | kube-prometheus-stack deployed as a Helm chart |
| ArgoCD / GitOps | App-of-apps pattern — commit triggers deploy |
| Prometheus + Grafana | Full observability stack with pre-built dashboards |
| GitLab CI / GitHub Actions | (in progress) |

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   GitHub Repository                  │
│                                                      │
│  terraform/          clusters/homelab/               │
│  ├── main.tf         ├── root-app.yaml  (ArgoCD)    │
│  ├── variables.tf    └── apps/                       │
│  └── outputs.tf          └── monitoring.yaml         │
│                                                      │
│  ansible/            clusters/homelab/monitoring/    │
│  ├── playbook.yml    ├── Chart.yaml                  │
│  └── roles/k3s/      └── values.yaml                │
└─────────────────────────────────────────────────────┘
         │                        │
         │ terraform apply        │ ArgoCD watches
         ▼                        ▼
┌─────────────────┐    ┌──────────────────────────────┐
│  Hetzner Cloud  │    │     k3s Cluster               │
│                 │    │                               │
│  CX22 VM        │    │  argocd/                      │
│  2 vCPU         │    │  ├── argocd-server            │
│  4 GB RAM       │    │  ├── argocd-repo-server       │
│  40 GB SSD      │    │  └── argocd-application-ctrl  │
│  nbg1           │    │                               │
│                 │    │  monitoring/                  │
│  Firewall:      │    │  ├── prometheus               │
│  22, 80, 443    │    │  ├── grafana                  │
│  6443, 30080    │    │  ├── alertmanager             │
│  30443, 31000   │    │  ├── kube-state-metrics       │
└─────────────────┘    │  └── node-exporter            │
         │             └──────────────────────────────┘
         │
         │ ansible-playbook
         ▼
  k3s installed + configured
  kubeconfig fetched locally
  ArgoCD bootstrapped via Helm
```

## Stack

| Layer | Technology |
|---|---|
| Cloud Provider | Hetzner Cloud (CX22, nbg1) |
| Infrastructure as Code | Terraform + hcloud provider |
| Configuration Management | Ansible |
| Kubernetes Distribution | k3s v1.30.4 |
| GitOps | ArgoCD v2.11.7 (app-of-apps pattern) |
| Monitoring | kube-prometheus-stack (Prometheus + Grafana + Alertmanager) |
| Package Manager | Helm |

## Dashboards

### Node Exporter — Host Metrics
CPU usage, memory (69.3% used), disk I/O and network traffic on the Hetzner VM.

![Node Exporter Dashboard](docs/screenshots/Screenshot_from_2026-06-09_11-33-17.png)

### Kubernetes / Compute Resources / Cluster
Resource utilisation across all namespaces — argocd, monitoring, kube-system.

![Cluster Resources Dashboard](docs/screenshots/Screenshot_from_2026-06-09_11-34-33.png)

### Kubernetes / Compute Resources / Namespace (Pods)
Per-pod CPU and memory breakdown showing Prometheus (482 MiB), ArgoCD application controller (177 MiB) and other components.

![Namespace Pods Dashboard](docs/screenshots/Screenshot_from_2026-06-09_11-35-15.png)

## Repository Structure

```
homelab-gitops/
├── terraform/                    # Hetzner Cloud infrastructure
│   ├── main.tf                   # VM, firewall, SSH key
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── ansible/                      # Server bootstrap
│   ├── playbook.yml              # Main playbook
│   └── roles/k3s/tasks/main.yml  # k3s install + kubeconfig fetch
├── clusters/homelab/
│   ├── root-app.yaml             # ArgoCD root Application (app-of-apps)
│   ├── apps/
│   │   └── monitoring.yaml       # Child Application for monitoring stack
│   └── monitoring/               # kube-prometheus-stack Helm chart
│       ├── Chart.yaml
│       └── values.yaml
├── docs/screenshots/             # Grafana dashboard screenshots
├── Makefile                      # make infra / make bootstrap / make all
└── .gitignore
```

## Quick Start

### Prerequisites
- Terraform >= 1.5.0
- Ansible
- kubectl
- A Hetzner Cloud account and API token
- An SSH key added to your Hetzner project

### 1. Configure

```bash
git clone https://github.com/yevhenii-poliakov/homelab-gitops
cd homelab-gitops

# Copy and fill in your values
cp ansible/inventory.ini.example ansible/inventory.ini
cp ansible/group_vars/all.yml.example ansible/group_vars/all.yml

# Create Terraform variables
cat > terraform/terraform.tfvars <<EOF
hcloud_token = "your-hetzner-api-token"
ssh_key_name = "your-ssh-key-name"
EOF
```

### 2. Provision infrastructure

```bash
make infra
# or: terraform -chdir=terraform apply
```

Terraform creates:
- CX22 VM (Ubuntu 24.04, nbg1)
- Firewall with rules for SSH, HTTP, HTTPS, k3s API and NodePorts

### 3. Bootstrap k3s

```bash
make bootstrap
# or: ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

Ansible installs k3s, configures UFW and writes the kubeconfig to `~/.kube/homelab.yaml`.

### 4. Verify cluster

```bash
export KUBECONFIG=~/.kube/homelab.yaml
kubectl get nodes
# NAME      STATUS   ROLES                  AGE   VERSION
# homelab   Ready    control-plane,master   ...   v1.30.4+k3s1
```

### 5. Bootstrap ArgoCD

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --version 7.3.11 \
  --set server.service.type=NodePort \
  --set server.service.nodePorts.http=30080 \
  --set server.service.nodePorts.https=30443 \
  --wait
```

### 6. Apply the root app

```bash
kubectl apply -f clusters/homelab/root-app.yaml
```

ArgoCD detects `clusters/homelab/apps/` and automatically deploys all child Applications — including the full monitoring stack.

## Makefile

```bash
make infra       # terraform apply
make bootstrap   # ansible-playbook
make all         # infra + bootstrap
```

## Observations

- Prometheus alone uses ~482 MiB on a 4 GB node — about 12% of available memory just for monitoring. Worth knowing before sizing a production cluster.
- ArgoCD + monitoring stack together use ~1.1 GB RAM, leaving ~2.5 GB for actual workloads on a CX22. Tight but workable for a homelab.
- `terraform.tfvars` and `inventory.ini` are gitignored — copy the `.example` files to get started.
- Terraform state is local. For a shared setup, migrate to an S3-compatible backend (e.g. Hetzner Object Storage).
- The CX22 VM costs ~4€/month — destroy it with `terraform destroy` when not in use.
