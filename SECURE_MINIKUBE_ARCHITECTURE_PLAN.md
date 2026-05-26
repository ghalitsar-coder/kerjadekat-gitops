# KerjaDekat Secure Minikube Architecture Plan

> Untuk local-only project kuliah Cloud Computing / DevOps, tapi dirancang mengikuti prinsip cloud architecture yang well-architected, secure, observable, dan scalable.

## 1. Goal

Membangun environment KerjaDekat di Minikube yang:
- secure by default
- zero-trust antar komponen
- mengikuti separation of concerns ala cloud architecture
- siap untuk HPA + load testing pakai k6
- observable via Prometheus/Grafana
- mudah dijelaskan saat presentasi akademik / demo proyek

## 2. Prinsip Arsitektur

Walaupun ini hanya local Minikube, desainnya akan meniru pola cloud production:

1. Defense in depth
2. Least privilege
3. Default deny network
4. Isolasi layer aplikasi dan data
5. Stateless app tier
6. Observable everything
7. Resource governance
8. GitOps-friendly

## 3. Logical Zones (analogi subnet / tier cloud)

### 3.1 Edge Zone
Komponen:
- Kong Ingress / API Gateway

Fungsi:
- satu-satunya pintu masuk traffic user
- routing / ke frontend
- routing /api/* ke backend
- nanti bisa ditambah rate limiting, auth plugin, CORS policy

Analogi cloud:
- public subnet / DMZ / edge layer

### 3.2 App Zone
Komponen:
- frontend
- backend

Fungsi:
- frontend hanya melayani UI
- backend jadi satu-satunya service bisnis yang boleh bicara ke data tier

Analogi cloud:
- private app subnet

### 3.3 Data Zone
Komponen:
- PostgreSQL + PostGIS
- Redis
- RabbitMQ

Fungsi:
- menyimpan data dan messaging internal
- tidak boleh bisa diakses langsung dari frontend
- tidak boleh expose ke ingress publik

Analogi cloud:
- private data subnet / restricted subnet

### 3.4 Ops Zone
Komponen:
- ArgoCD
- Prometheus
- Grafana
- Elasticsearch/logging

Fungsi:
- observability, audit, deployment operations

Analogi cloud:
- management subnet / ops subnet

## 4. Desired Traffic Rules

### Allowed flows
1. User -> Kong
2. Kong -> Frontend
3. Kong -> Backend
4. Backend -> PostgreSQL
5. Backend -> Redis
6. Backend -> RabbitMQ
7. Prometheus -> scrape selected services/pods
8. ArgoCD -> Kubernetes API / managed resources

### Denied flows
1. Frontend -> PostgreSQL
2. Frontend -> Redis
3. Frontend -> RabbitMQ
4. Frontend -> ArgoCD
5. Frontend -> Monitoring
6. PostgreSQL -> Frontend
7. Redis -> Frontend
8. RabbitMQ -> Frontend
9. Any namespace -> data zone by default
10. Semua pod ke semua pod tanpa policy

## 5. Security Controls yang Akan Diimplementasikan

### 5.1 NetworkPolicy
Target implementasi:
- default deny ingress + egress untuk namespace aplikasi dan data
- allow spesifik berdasarkan label

Policy minimum:
1. default-deny untuk namespace kerjadekat
2. default-deny untuk namespace kerjadekat-infra
3. allow Kong -> frontend
4. allow Kong -> backend
5. allow backend -> PostgreSQL :5432
6. allow backend -> Redis :6379
7. allow backend -> RabbitMQ :5672
8. allow Prometheus -> metrics endpoints

Catatan:
NetworkPolicy butuh CNI yang mendukung enforcement. Untuk Minikube docker driver, biasanya perlu plugin seperti Calico atau Cilium. Jadi ada 2 mode:
- mode desain/dokumentasi penuh
- mode implementasi nyata jika CNI enforcement tersedia

### 5.2 Pod Security Hardening
Semua deployment app akan diarahkan ke:
- runAsNonRoot: true
- allowPrivilegeEscalation: false
- readOnlyRootFilesystem: true (jika image memungkinkan)
- seccompProfile: RuntimeDefault
- drop all capabilities

Prioritas implementasi:
1. frontend
2. backend
3. kong bila kompatibel

### 5.3 Secret Hygiene
Target:
- semua credential masuk Secret, bukan ConfigMap
- frontend tidak menyimpan credential sensitif
- rotasi password default untuk PostgreSQL / RabbitMQ / Grafana jika perlu

### 5.4 Gateway Hardening
Kong akan diarahkan untuk punya:
- rate limiting
- CORS policy yang jelas
- optional request size limits
- optional auth layer di masa depan

### 5.5 Resource Governance
Setiap workload harus punya:
- requests
- limits
- readinessProbe
- livenessProbe
- HPA untuk workload stateless

## 6. HPA Strategy

### 6.1 Status saat ini
HPA file SUDAH ADA di repo untuk:
- backend
- frontend

Namun saat ini belum di-apply ke cluster.

### 6.2 Saran final HPA untuk Minikube demo
Backend:
- minReplicas: 2
- maxReplicas: 6
- CPU target: 60%
- Memory target: 80%

Frontend:
- minReplicas: 2
- maxReplicas: 4
- CPU target: 70%

Kenapa diturunkan dari max besar?
- supaya realistis untuk laptop lokal
- lebih mudah dilihat saat demo
- tidak membuang resource

### 6.3 Prasyarat HPA
- metrics-server aktif
- deployment punya requests CPU/memory
- workload cukup load untuk trigger scaling

## 7. Load Test Plan dengan k6

### Objective
Membuktikan HPA backend bereaksi terhadap beban.

### Skenario tahap 1
- endpoint: /api/health atau endpoint GET ringan
- VUs: 10 -> 25 -> 50 -> 75
- duration: 1-3 menit per stage

### Skenario tahap 2
- endpoint API yang lebih realistis
- burst traffic
- lihat scale out backend

### Verifikasi
Command:
- kubectl get hpa -n kerjadekat -w
- kubectl get pods -n kerjadekat -w
- kubectl top pods -n kerjadekat

Ekspektasi:
- CPU utilization naik
- replicas backend bertambah
- setelah load berhenti, replicas turun lagi

## 8. Observability Target

### Metrics
- pod CPU/memory
- deployment replicas
- HPA metrics
- Kong traffic
- backend latency/error rate (jika metrics app tersedia)

### Logging
- backend logs
- Kong logs
- RabbitMQ logs
- PostgreSQL logs

### Dashboards
Grafana minimal punya:
1. cluster overview
2. app overview
3. HPA scaling dashboard
4. ingress traffic dashboard

## 9. Well-Architected Mapping

### Security
- namespace separation
- default deny network
- least privilege
- secret isolation
- gateway hardening

### Reliability
- health probes
- HPA
- stateless app deployment
- broker + cache + db dipisah

### Performance Efficiency
- requests/limits
- HPA
- Redis caching
- RabbitMQ untuk async workload

### Operational Excellence
- ArgoCD
- monitoring
- documented architecture
- repeatable manifests

### Cost Optimization (versi local/laptop)
- replicas kecil saat idle
- limit max replicas
- resource limits realistis
- hanya komponen penting yang aktif

## 10. Implementation Roadmap

### Phase A — Fix aplikasi dulu
1. perbaiki frontend blank white screen
2. verifikasi frontend + backend via Kong

### Phase B — Enable autoscaling
1. apply HPA backend/frontend
2. verifikasi metrics-server
3. test HPA manual

### Phase C — Security baseline
1. buat namespace labels yang konsisten
2. buat default deny policies
3. allow-list traffic antar layer
4. uji frontend tidak bisa akses DB langsung

### Phase D — Hardening
1. securityContext backend/frontend
2. harden Kong config
3. review secrets dan password default

### Phase E — Performance demo
1. buat script k6
2. jalankan load test
3. capture scaling evidence
4. buat dashboard / screenshot demo notes

## 11. Bukti yang Bagus untuk Presentasi

Saat presentasi, tunjukkan:
1. diagram logical zones
2. `kubectl get networkpolicy -A`
3. `kubectl get hpa -n kerjadekat`
4. `kubectl top pods -n kerjadekat`
5. k6 load test berjalan
6. pod backend scale dari 2 ke 3/4
7. frontend tidak bisa akses PostgreSQL langsung

## 12. Catatan Penting Realistis

Karena ini Minikube lokal:
- tidak ada VPC/subnet asli seperti AWS/Azure
- tapi kita bisa meniru konsep subnet dengan namespace + NetworkPolicy + ingress boundaries
- keamanan yang paling relevan di Kubernetes lokal adalah isolasi trafik pod-to-pod, secret handling, non-root container, dan gateway control
- jadi narasi presentasinya adalah: “arsitektur ini mengikuti cloud design principles meskipun dijalankan secara lokal di Minikube.”

## 13. Deliverables yang Saya Sarankan Setelah Ini

1. Fix frontend SPA build
2. Apply HPA ke cluster
3. Audit dan tuning HPA untuk laptop local
4. Implement NetworkPolicy baseline
5. Hardening securityContext backend/frontend
6. Buat k6 test script
7. Jalankan demo scaling
8. Tambahkan diagram arsitektur
