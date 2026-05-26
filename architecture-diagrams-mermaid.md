# KerjaDekat Architecture Diagrams (Mermaid)

## 1. High-Level Architecture

```mermaid
flowchart TD
    U[User / Browser] --> K[Kong API Gateway]

    subgraph APP_NS[Namespace: kerjadekat]
        F[Frontend Pod(s)]
        B[Backend Pod(s)]
        HPA1[HPA Frontend]
        HPA2[HPA Backend]
    end

    subgraph INFRA_NS[Namespace: kerjadekat-infra]
        PG[PostgreSQL + PostGIS]
        R[Redis]
        MQ[RabbitMQ]
    end

    subgraph OPS_NS[Operations Layer]
        A[ArgoCD]
        P[Prometheus]
        G[Grafana]
        L[Logging / Elasticsearch]
    end

    U -->|HTTP| K
    K -->|Route /| F
    K -->|Route /api/*| B
    K -->|Route /ws| B

    F -->|API calls| B
    B -->|SQL| PG
    B -->|Cache| R
    B -->|Async messaging| MQ

    A -->|GitOps Sync| APP_NS
    A -->|GitOps Sync| INFRA_NS
    P -->|Scrape metrics| F
    P -->|Scrape metrics| B
    P -->|Scrape metrics| PG
    P -->|Scrape metrics| MQ
    G -->|Visualize| P

    HPA1 -->|Scale Frontend| F
    HPA2 -->|Scale Backend| B
```

## 2. Layered Cloud-like Architecture

```mermaid
flowchart TB
    subgraph EDGE[Edge / Public Zone]
        K[Kong API Gateway]
    end

    subgraph APP[Application Zone]
        F[Frontend]
        B[Backend]
    end

    subgraph DATA[Restricted Data Zone]
        PG[PostgreSQL]
        R[Redis]
        MQ[RabbitMQ]
    end

    subgraph OPS[Operations Zone]
        A[ArgoCD]
        P[Prometheus]
        G[Grafana]
        LOG[Logging]
    end

    USER[User] --> K
    K --> F
    K --> B
    F --> B
    B --> PG
    B --> R
    B --> MQ
    A --> APP
    A --> DATA
    P --> APP
    P --> DATA
    G --> P
```

## 3. Request Flow

```mermaid
sequenceDiagram
    participant User
    participant Kong
    participant Frontend
    participant Backend
    participant PostgreSQL
    participant Redis
    participant RabbitMQ

    User->>Kong: Request page / or API
    Kong->>Frontend: Serve UI route
    Frontend->>Kong: Request API
    Kong->>Backend: Forward /api/*
    Backend->>Redis: Read cache / session / fast lookup
    Backend->>PostgreSQL: Query persistent data
    Backend->>RabbitMQ: Publish async job/event if needed
    PostgreSQL-->>Backend: Query result
    Redis-->>Backend: Cache result
    Backend-->>Kong: API response
    Kong-->>Frontend: API payload
    Frontend-->>User: Render result
```

## 4. Security Boundary Diagram

```mermaid
flowchart LR
    U[User] --> K[Kong Gateway]
    K --> F[Frontend]
    K --> B[Backend]

    F -. allowed .-> B
    B --> PG[PostgreSQL]
    B --> R[Redis]
    B --> MQ[RabbitMQ]

    F -. should NOT access .-> PG
    F -. should NOT access .-> R
    F -. should NOT access .-> MQ
```

## 5. GitOps Flow

```mermaid
flowchart LR
    DEV[Developer / Git Commit] --> GIT[Git Repository]
    GIT --> ARGO[ArgoCD]
    ARGO --> K8S[Kubernetes Cluster]
    K8S --> APP[Applications + Infra]
```

## 6. HPA Scaling Flow

```mermaid
flowchart TD
    LOAD[k6 Load Test] --> K[Kong]
    K --> F[Frontend Pods]
    F --> METRIC[CPU Usage Increases]
    METRIC --> HPA[Horizontal Pod Autoscaler]
    HPA --> SCALE[Scale from 2 to 10 Pods]
    SCALE --> STABLE[Traffic distributed across more pods]
    STABLE --> COOLDOWN[Load stops / cooldown]
    COOLDOWN --> DOWN[Scale down back to min replicas]
```

## 7. Presentation-Friendly Summary Diagram

```mermaid
flowchart TD
    A[User Access] --> B[Kong API Gateway]
    B --> C[Frontend Layer]
    B --> D[Backend Layer]
    D --> E[PostgreSQL]
    D --> F[Redis]
    D --> G[RabbitMQ]
    H[ArgoCD] --> C
    H --> D
    H --> E
    H --> F
    H --> G
    I[Prometheus + Grafana] --> C
    I --> D
    I --> E
    I --> G
    J[HPA] --> C
    J --> D
```

## Catatan Presentasi

Kalau kamu ingin menjelaskan diagram ini dengan sederhana:
- semua request masuk dari Kong
- Kong meneruskan ke frontend atau backend
- backend adalah satu-satunya jalur resmi menuju database, cache, dan message broker
- ArgoCD mengatur deployment berbasis GitOps
- Prometheus dan Grafana memonitor sistem
- HPA menambah pod saat beban naik
- desain security membatasi akses antar layer

