# Panduan Lengkap: Migrasi KerjaDekat ke Minikube

> **Tanggal:** Mei 2025
> **OS:** CachyOS (Arch-based) + Fish Shell
> **Status:** Development / Local Minikube

---

## Daftar Isi

- [Peta Besar Proyek](#peta-besar-proyek)
- [Fase 0: Pengecekan & Instalasi Prerequisites](#fase-0-pengecekan--instalasi-prerequisites)
- [Fase 1: Setup & Verifikasi Tools](#fase-1-setup--verifikasi-tools)
  - [1.1 Stop Docker Compose Lokal](#11-stop-docker-compose-lokal)
  - [1.2 Start Minikube](#12-start-minikube)
  - [1.3 Enable Addons Minikube](#13-enable-addons-minikube)
  - [1.4 Build Docker Image PostgreSQL PostGIS](#14-build-docker-image-postgresql-postgis)
  - [1.5 Buat Namespaces](#15-buat-namespaces)
  - [1.6 Deploy Secret & ConfigMap](#16-deploy-secret--configmap)
  - [1.7 Install ArgoCD](#17-install-argocd)
  - [1.8 Setup Jenkins](#18-setup-jenkins)
- [Fase 2: Deploy Infrastruktur ke Minikube](#fase-2-deploy-infrastruktur-ke-minikube)
  - [2.1 Deploy PostgreSQL](#21-deploy-postgresql)
  - [2.2 Deploy Redis](#22-deploy-redis)
  - [2.3 Deploy RabbitMQ](#23-deploy-rabbitmq)
  - [2.4 Deploy Kong API Gateway](#24-deploy-kong-api-gateway)
  - [2.5 Build & Deploy Backend](#25-build--deploy-backend)
  - [2.6 Build & Deploy Frontend](#26-build--deploy-frontend)
  - [2.7 Apply Kong Routes](#27-apply-kong-routes)
  - [2.8 Deploy Monitoring (Opsional)](#28-deploy-monitoring-opsional)
  - [2.9 Setup ArgoCD GitOps](#29-setup-argocd-gitops)
- [Fase 3: Verifikasi & Troubleshooting](#fase-3-verifikasi--troubleshooting)
  - [3.1 Cek Semua Pods](#31-cek-semua-pods)
  - [3.2 Cek Services](#32-cek-services)
  - [3.3 Akses Aplikasi](#33-akses-aplikasi)
  - [3.4 Baca Logs](#34-baca-logs)
  - [3.5 Troubleshooting Umum](#35-troubleshooting-umum)
  - [3.6 Perintah Berguna](#36-perintah-berguna)
- [Ringkasan Port & URL](#ringkasan-port--url)

---

## Peta Besar Proyek

### Struktur Direktori Utama

```
kerjadekat-gitops/
├── gitops/                    # File konfigurasi Kubernetes (manifests)
│   ├── argocd/                # ArgoCD Application definitions
│   │   ├── applications/      # 8 app: backend, frontend, kong, pg, redis, rmq, monitoring, logging
│   │   ├── project.yaml       # AppProject "kerjadekat"
│   │   └── root-application.yaml  # App-of-Apps root
│   ├── base/                  # Kubernetes manifests utama
│   │   ├── backend/           # Deployment, Service, HPA, ConfigMap, Secret
│   │   ├── frontend/          # Deployment, Service, HPA, ConfigMap
│   │   ├── infra/             # PostgreSQL StatefulSet, Redis/RabbitMQ Helm values
│   │   └── namespaces.yaml    # 6 namespaces
│   ├── kong/                  # HTTPRoute & KongPlugin
│   ├── production/            # (Belum diisi) overlay untuk production
│   └── staging/               # (Belum diisi) overlay untuk staging
│
└── infrastructure/            # Alat bantu setup
    ├── docker/                # Dockerfile custom (frontend nginx, postgres-postgis)
    ├── jenkins/               # Jenkins CI (Dockerfile, docker-compose, CasC config)
    ├── postgres/              # Seed data & skill docs
    └── scripts/               # Shell scripts untuk bootstrap
        ├── 01-install-argocd.sh
        ├── 02-bootstrap-gitops.sh
        └── 03-minikube-start.sh
```

### Tools & Fungsinya

| Tool | Fungsi (Bahasa Awam) |
|---|---|
| **Minikube** | Bikin Kubernetes mini di laptop kamu. Kubernetes itu sistem yang jalanin banyak container secara otomatis. |
| **ArgoCD** | Robot yang otomatis deploy. Dia ngecek Git terus-menerus, kalau ada perubahan YAML langsung diterapkan ke K8s. Ini namanya "GitOps". |
| **Kong** | Satpam & resepsionis. Semua request masuk lewat Kong: `/api/v1/*` → backend, `/` → frontend. Juga rate limiting. |
| **PostgreSQL + PostGIS** | Database utama + ekstensi untuk data lokasi/peta. |
| **Redis** | Memori cepat untuk cache, session, lokasi pekerja online, pub/sub WebSocket. |
| **RabbitMQ** | Pengantar pesan antar service untuk proses async (timer 60 detik order, notifikasi). |
| **Jenkins** | Tukang build otomatis: test → build Docker → push DockerHub → update YAML → ArgoCD deploy. |
| **Prometheus + Grafana** | CCTV & dashboard monitoring (CPU, memori, request count, WebSocket). |
| **Elasticsearch** | Mesin pencari log untuk agregasi log semua pod. |

### Alur Kerja GitOps

```
Developer push code
       │
       ▼
Jenkins build & push Docker image ke DockerHub
       │
       ▼
Jenkins update image tag di file YAML (gitops/base/*)
       │
       ▼
ArgoCD deteksi perubahan di Git
       │
       ▼
ArgoCD otomatis deploy ke Kubernetes (Minikube)
       │
       ▼
Kong routing traffic ke frontend & backend
       │
       ▼
User akses via http://<minikube-ip>:30080
```

---

## Fase 0: Pengecekan & Instalasi Prerequisites

### Tools yang Dibutuhkan

| Tool | Cek Versi | Install (kalau belum ada) |
|---|---|---|
| Docker | `docker --version` | `sudo pacman -S docker` lalu `sudo systemctl enable --now docker` dan `sudo usermod -aG docker $USER` |
| Minikube | `minikube version` | `sudo pacman -S minikube` |
| kubectl | `kubectl version --client` | `sudo pacman -S kubectl` |
| Helm | `helm version --short` | `sudo pacman -S helm` |
| Git | `git --version` | `sudo pacman -S git` |
| ArgoCD CLI (opsional) | `argocd version --client` | `yay -S argocd-bin` |

### Cek Resource Mesin

```fish
# Minimal: 6 CPU, 16 GB RAM, 60 GB disk free
nproc                    # Cek jumlah CPU
free -h                  # Cek RAM
df -h /                  # Cek disk
```

### Verifikasi Docker Berjalan

```fish
# Docker harus aktif dan user harus di group docker
systemctl is-active docker          # Harus: active
groups | grep docker                # Harus muncul "docker"

# Kalau docker belum aktif:
sudo systemctl enable --now docker

# Kalau user belum di group docker:
sudo usermod -aG docker $USER
# Lalu LOGOUT dan LOGIN ulang
```

---

## Fase 1: Setup & Verifikasi Tools

### 1.1 Stop Docker Compose Lokal

```fish
# Matikan postgres, redis, rabbitmq yang jalan via docker-compose
# supaya tidak bentrok port saat Minikube jalan.
cd ~/Kuliah/CLOUD/KerjaDekat/backend
docker compose down

# Verifikasi: tidak ada container KerjaDekat yang jalan
docker ps | grep kerjadekat
# Harusnya kosong
```

### 1.2 Start Minikube

```fish
cd ~/Kuliah/CLOUD/KerjaDekat/kerjadekat-gitops

minikube start \
  --cpus=6 \
  --memory=16384 \
  --disk-size=60g \
  --driver=docker \
  --kubernetes-version=v1.29.0

# Penjelasan parameter:
#   --cpus=6        : Kasih 6 core CPU ke Minikube
#   --memory=16384  : Kasih 16 GB RAM
#   --disk-size=60g : Kasih 60 GB disk virtual
#   --driver=docker : Pakai Docker sebagai backend Minikube
#   --kubernetes-version=v1.29.0 : Versi Kubernetes

# CATATAN: Pertama kali butuh beberapa menit (download image K8s)
```

### 1.3 Enable Addons Minikube

```fish
# metrics-server: supaya HPA (auto-scaling) bisa baca data CPU/memori
minikube addons enable metrics-server

# ingress: supaya K8s bisa handle routing HTTP masuk
minikube addons enable ingress

# Verifikasi cluster jalan
kubectl cluster-info
# Harus muncul: "Kubernetes control plane is running at..."

kubectl get nodes -o wide
# Harus muncul 1 node dengan STATUS = Ready
```

### 1.4 Build Docker Image PostgreSQL PostGIS

```fish
# Arahkan Docker CLI ke Docker daemon di DALAM Minikube
# (khusus Fish shell)
eval (minikube docker-env)

# Build image PostgreSQL + PostGIS custom
cd ~/Kuliah/CLOUD/KerjaDekat/kerjadekat-gitops/infrastructure/docker/postgres-postgis
docker build -t kerjadekat/postgres-postgis:17-3.5 .

# Verifikasi image ada
docker images | grep kerjadekat
# Harus muncul: kerjadekat/postgres-postgis   17-3.5
```

### 1.5 Buat Namespaces

```fish
cd ~/Kuliah/CLOUD/KerjaDekat/kerjadekat-gitops

kubectl apply -f gitops/base/namespaces.yaml

# Ini membuat 6 namespace:
#   kerjadekat       : tempat backend & frontend
#   kerjadekat-infra : tempat postgres, redis, rabbitmq
#   kong             : tempat API Gateway
#   monitoring       : tempat Prometheus + Grafana
#   logging          : tempat Elasticsearch
#   jenkins          : tempat Jenkins (opsional deploy di K8s)

# Verifikasi
kubectl get namespaces
```

### 1.6 Deploy Secret & ConfigMap

```fish
cd ~/Kuliah/CLOUD/KerjaDekat/kerjadekat-gitops

# Secret berisi password DB, JWT secret, API keys
kubectl apply -f gitops/base/backend/secret.yaml

# ConfigMap berisi konfigurasi non-rahasia
kubectl apply -f gitops/base/backend/configmap.yaml

# Verifikasi
kubectl get secret -n kerjadekat
kubectl get configmap -n kerjadekat
```

> **CATATAN:** File `secret.yaml` berisi nilai PLACEHOLDER (`CHANGE_ME`).
> Untuk development lokal ini OK. Untuk production, ganti dengan nilai asli
> dan gunakan SealedSecrets atau HashiCorp Vault.

### 1.7 Install ArgoCD

```fish
cd ~/Kuliah/CLOUD/KerjaDekat/kerjadekat-gitops

chmod +x infrastructure/scripts/01-install-argocd.sh
bash infrastructure/scripts/01-install-argocd.sh

# Script ini:
#   1. Buat namespace "argocd"
#   2. Install ArgoCD v2.13.0 dari manifest resmi
#   3. Tunggu sampai siap (max 5 menit)
#   4. Print password admin

# === CATAT PASSWORD ADMIN YANG MUNCUL! ===
```

**Akses ArgoCD UI:**

```fish
# Buka terminal BARU, jalankan:
kubectl port-forward svc/argocd-server -n argocd 8081:80

# Buka browser: http://localhost:8081
# Username: admin
# Password: (yang tadi dicatat dari output script)
```

### 1.8 Setup Jenkins

Jenkins jalan di Docker biasa (bukan K8s), karena butuh akses Docker socket untuk build image.

```fish
cd ~/Kuliah/CLOUD/KerjaDekat/kerjadekat-gitops/infrastructure/jenkins

# Set credential DockerHub (ganti dengan milikmu)
set -x DOCKER_USERNAME "username_dockerhub_kamu"
set -x DOCKER_PASSWORD "password_atau_token_kamu"

# Start Jenkins
docker compose up -d

# Tunggu ~2 menit, lalu verifikasi
docker ps | grep jenkins
# Harus muncul "kerjadekat_jenkins" dengan status Up
```

**Akses Jenkins UI:** `http://localhost:8080`

> **Port berbeda:** Jenkins = `:8080`, ArgoCD = `:8081`

---

## Fase 2: Deploy Infrastruktur ke Minikube

### 2.1 Deploy PostgreSQL

```fish
cd ~/Kuliah/CLOUD/KerjaDekat/kerjadekat-gitops

kubectl apply -f gitops/base/infra/postgresql-statefulset.yaml

# Deploy PostgreSQL sebagai StatefulSet:
#   - 10 GB persistent storage
#   - Image custom kerjadekat/postgres-postgis:17-3.5
#   - Credentials dari secret
#   - PostGIS extensions otomatis aktif

# Tunggu sampai ready
kubectl get pods -n kerjadekat-infra -w
# Tunggu STATUS = Running, lalu Ctrl+C
```

### 2.2 Deploy Redis

```fish
# Tambah repo Helm Bitnami
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install Redis
helm install redis bitnami/redis \
  -n kerjadekat-infra \
  -f gitops/base/infra/redis-values.yaml

# Konfigurasi:
#   - Standalone mode (1 node, cukup untuk dev)
#   - Tanpa password
#   - 2 GB storage

# Tunggu ready
kubectl get pods -n kerjadekat-infra -w
```

### 2.3 Deploy RabbitMQ

```fish
helm install rabbitmq bitnami/rabbitmq \
  -n kerjadekat-infra \
  -f gitops/base/infra/rabbitmq-values.yaml

# Konfigurasi:
#   - Plugin delayed message exchange (timer 60 detik order)
#   - Username/password: guest/guest
#   - 2 GB storage

# Tunggu ready
kubectl get pods -n kerjadekat-infra -w
```

### 2.4 Deploy Kong API Gateway

```fish
helm repo add kong https://charts.konghq.com
helm repo update

helm install kong kong/kong \
  -n kong \
  --set ingressController.enabled=true \
  --set ingressController.installCRDs=true \
  --set env.database=off \
  --set proxy.type=NodePort \
  --set proxy.http.nodePort=30080 \
  --set proxy.https.nodePort=30443 \
  --set admin.enabled=true \
  --set admin.type=ClusterIP

# Kong sebagai API Gateway:
#   - Ingress Controller aktif (baca HTTPRoute)
#   - DB-less mode
#   - NodePort 30080 (HTTP), 30443 (HTTPS)
#   - Admin API internal saja

# Tunggu ready
kubectl get pods -n kong -w
```

### 2.5 Build & Deploy Backend

```fish
# Pastikan Docker CLI mengarah ke Minikube
eval (minikube docker-env)

# Build backend image
cd ~/Kuliah/CLOUD/KerjaDekat/backend
docker build -t YOUR_DOCKERHUB_USER/kerjadekat-backend:latest .
# Ganti YOUR_DOCKERHUB_USER dengan username DockerHub-mu

# PENTING: Edit deployment.yaml sebelum deploy
# Ubah imagePullPolicy: Always → IfNotPresent
# Ubah image name ke username DockerHub-mu
# File: gitops/base/backend/deployment.yaml

# Deploy
cd ~/Kuliah/CLOUD/KerjaDekat/kerjadekat-gitops
kubectl apply -f gitops/base/backend/deployment.yaml
kubectl apply -f gitops/base/backend/service.yaml
kubectl apply -f gitops/base/backend/hpa.yaml
```

### 2.6 Build & Deploy Frontend

```fish
eval (minikube docker-env)

cd ~/Kuliah/CLOUD/KerjaDekat/frontend
docker build \
  -f ~/Kuliah/CLOUD/KerjaDekat/kerjadekat-gitops/infrastructure/docker/frontend/Dockerfile \
  -t YOUR_DOCKERHUB_USER/kerjadekat-frontend:latest .

# Deploy
cd ~/Kuliah/CLOUD/KerjaDekat/kerjadekat-gitops
kubectl apply -f gitops/base/frontend/deployment.yaml
kubectl apply -f gitops/base/frontend/service.yaml
kubectl apply -f gitops/base/frontend/hpa.yaml
```

### 2.7 Apply Kong Routes

```fish
cd ~/Kuliah/CLOUD/KerjaDekat/kerjadekat-gitops

kubectl apply -f gitops/kong/kongplugin-ratelimit.yaml
# Rate limit: 100 request/menit per IP

kubectl apply -f gitops/kong/ingress-backend.yaml
# Route: /api/v1/* → backend-svc:8080

kubectl apply -f gitops/kong/ingress-frontend.yaml
# Route: /* → frontend-svc:80
```

### 2.8 Deploy Monitoring (Opsional)

```fish
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts
helm repo update

helm install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --set grafana.enabled=true \
  --set grafana.adminPassword=admin \
  --set grafana.service.type=ClusterIP \
  --set prometheus.prometheusSpec.retention=7d \
  --set alertmanager.enabled=false

# Akses Grafana:
# kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
# Buka: http://localhost:3000 (admin/admin)
```

### 2.9 Setup ArgoCD GitOps

```fish
cd ~/Kuliah/CLOUD/KerjaDekat/kerjadekat-gitops

# Set URL repo Git-mu
set -x GITOPS_REPO_URL "https://github.com/USERNAME_KAMU/kerjadekat"

chmod +x infrastructure/scripts/02-bootstrap-gitops.sh
bash infrastructure/scripts/02-bootstrap-gitops.sh

# Script ini:
#   1. Update URL repo di YAML files
#   2. Apply AppProject ke ArgoCD
#   3. Apply Root Application (App-of-Apps)
#
# ArgoCD akan otomatis sync semua 8 aplikasi!

# Watch progress
kubectl get applications -n argocd -w
```

---

## Fase 3: Verifikasi & Troubleshooting

### 3.1 Cek Semua Pods

```fish
# Semua pod di semua namespace
kubectl get pods --all-namespaces

# Per namespace
kubectl get pods -n kerjadekat           # backend, frontend
kubectl get pods -n kerjadekat-infra     # postgres, redis, rabbitmq
kubectl get pods -n kong                 # kong gateway
kubectl get pods -n argocd               # argocd components
kubectl get pods -n monitoring           # prometheus, grafana
```

**Yang diharapkan:** Semua pod STATUS = `Running` dan READY = `x/x`

### 3.2 Cek Services

```fish
kubectl get svc --all-namespaces

# Pastikan ada:
#   backend-svc      (kerjadekat, port 8080)
#   frontend-svc     (kerjadekat, port 80)
#   postgresql-svc   (kerjadekat-infra, port 5432)
#   redis-master     (kerjadekat-infra, port 6379)
#   rabbitmq         (kerjadekat-infra, port 5672)
```

### 3.3 Akses Aplikasi

```fish
# Dapatkan Minikube IP
minikube ip

# Akses via browser:
#   Frontend : http://<minikube-ip>:30080/
#   API      : http://<minikube-ip>:30080/api/v1/health
```

### 3.4 Baca Logs

```fish
# Lihat detail kenapa pod gagal
kubectl describe pod <NAMA_POD> -n <NAMESPACE>

# Baca log dari pod
kubectl logs <NAMA_POD> -n <NAMESPACE>

# Log dari instance sebelumnya (kalau pod restart terus)
kubectl logs <NAMA_POD> -n <NAMESPACE> --previous

# Follow log secara real-time
kubectl logs -f <NAMA_POD> -n <NAMESPACE>
```

### 3.5 Troubleshooting Umum

| Masalah | Penyebab Umum | Solusi |
|---|---|---|
| Pod **Pending** lama | Kurang resource (CPU/RAM) atau PVC belum terbuat | `kubectl describe pod <nama> -n <ns>` untuk detail |
| Pod **ImagePullBackOff** | Image Docker tidak ditemukan | Cek nama image, pastikan sudah build di Minikube, set `imagePullPolicy: IfNotPresent` |
| Pod **CrashLoopBackOff** | Config salah, DB belum siap, error aplikasi | `kubectl logs <nama> -n <ns> --previous` |
| Tidak bisa akses browser | Kong belum ready atau port salah | `minikube service kong-kong-proxy -n kong --url` |
| ArgoCD sync gagal | Repo URL salah atau private tanpa credential | Cek di ArgoCD UI, tab "Events" |

### 3.6 Perintah Berguna

```fish
# Semua kejadian terbaru di cluster
kubectl get events --all-namespaces --sort-by=.metadata.creationTimestamp

# Pemakaian CPU & memori tiap pod
kubectl top pods --all-namespaces

# Status sync ArgoCD
kubectl get applications -n argocd

# Dashboard visual Kubernetes
minikube dashboard

# Stop cluster (data tetap tersimpan)
minikube stop

# Start ulang cluster
minikube start

# Hapus cluster (SEMUA DATA HILANG!)
minikube delete
```

---

## Ringkasan Port & URL

| Service | URL | Port | Cara Akses |
|---|---|---|---|
| Frontend | `http://<minikube-ip>:30080/` | 30080 | Langsung via browser |
| Backend API | `http://<minikube-ip>:30080/api/v1/` | 30080 | Via Kong routing |
| ArgoCD UI | `http://localhost:8081` | 8081 | `kubectl port-forward svc/argocd-server -n argocd 8081:80` |
| Jenkins UI | `http://localhost:8080` | 8080 | Docker container langsung |
| Grafana | `http://localhost:3000` | 3000 | `kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80` |
| RabbitMQ Mgmt | `http://localhost:15672` | 15672 | `kubectl port-forward svc/rabbitmq -n kerjadekat-infra 15672:15672` |
| K8s Dashboard | (otomatis) | — | `minikube dashboard` |

---

## Catatan Penting

1. **Secret Management:** File `secret.yaml` berisi nilai placeholder. Untuk production, gunakan SealedSecrets atau HashiCorp Vault.
2. **Image Registry:** Untuk deployment via ArgoCD, image harus sudah di-push ke DockerHub. Jenkins menangani ini otomatis.
3. **Persistent Data:** PostgreSQL menggunakan PersistentVolumeClaim 10 GB. Data tetap aman walau pod restart, tapi hilang kalau `minikube delete`.
4. **Resource:** Minikube dikonfigurasi dengan 6 CPU dan 16 GB RAM. Pastikan laptop tidak kehabisan resource saat menjalankan semua service.

---

## Quick Access — Cheat Sheet

### Start Minikube (setelah reboot/shutdown)

```bash
minikube start
```

### Port-Forward untuk Akses Browser

```bash
# Kong API Gateway (Frontend + Backend)
kubectl port-forward -n kong svc/kong-kong-proxy 9080:80

# ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8081:443

# Grafana Dashboard
kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3000:80

# RabbitMQ Management UI
kubectl port-forward -n kerjadekat-infra svc/rabbitmq 15672:15672
```

### URLs setelah port-forward

| Service | URL | Credentials |
|---------|-----|-------------|
| Frontend | http://localhost:9080/ | - |
| Backend API | http://localhost:9080/api/health | - |
| ArgoCD | https://localhost:8081/ | admin / (lihat password di bawah) |
| Grafana | http://localhost:3000/ | admin / (lihat password di bawah) |
| RabbitMQ | http://localhost:15672/ | guest / guest |

### Dapatkan Password

```bash
# ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo

# Grafana admin password
kubectl get secret -n monitoring kube-prometheus-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

### Cek Status Semua Pods

```bash
kubectl get pods -A | grep -v kube-system
```

### Cek Logs

```bash
kubectl logs -n kerjadekat deploy/kerjadekat-backend --tail=50
kubectl logs -n kerjadekat deploy/kerjadekat-frontend --tail=50
kubectl logs -n kerjadekat-infra rabbitmq-0 --tail=50
kubectl logs -n kerjadekat-infra postgresql-0 --tail=50
```

### Rebuild Image (setelah code change)

```bash
# Masuk ke Minikube Docker environment
eval $(minikube docker-env --shell bash)

# Rebuild backend
docker build -t ghalitsar/kerjadekat-backend:latest ./backend/
kubectl rollout restart deployment/kerjadekat-backend -n kerjadekat

# Rebuild frontend
docker build -t ghalitsar/kerjadekat-frontend:latest -f infrastructure/docker/frontend/Dockerfile ./frontend/
kubectl rollout restart deployment/kerjadekat-frontend -n kerjadekat
```
