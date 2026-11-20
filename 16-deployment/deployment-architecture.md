# KIẾN TRÚC TRIỂN KHAI & HẠ TẦNG (DEPLOYMENT ARCHITECTURE)
**Hệ thống:** CommerceFlow Infrastructure & DevOps  
**Công nghệ:** Docker Compose (Local Dev) / Kubernetes (Production Topology)  
**Phiên bản:** 1.0.0  

---

## 1. MÔ HÌNH HẠ TẦNG MÔI TRƯỜNG PHÁT TRIỂN (LOCAL DOCKER TOPOLOGY)

```mermaid
graph TD
    subgraph Client Traffic
        Client[Host Machine Browser / Postman / k6] -->|Port 8080| APIGW[api-gateway]
    end

    subgraph Core Application Containers
        APIGW --> OrderSvc[order-service:8081]
        APIGW --> OrchSvc[order-orchestrator:8082]
        APIGW --> InvSvc[inventory-service:8083]
        APIGW --> PaySvc[payment-service:8084]
        APIGW --> PromoSvc[promotion-service:8085]
        APIGW --> ProdSvc[product-service:8086]
        APIGW --> CartSvc[cart-service:8087]
        APIGW --> ShipSvc[shipping-service:8088]
    end

    subgraph Data & Cache Tier
        OrderDB[(Postgres Order:5432)]
        InvDB[(Postgres Inv:5433)]
        PayDB[(Postgres Pay:5434)]
        Redis[(Redis:6379)]
    end

    subgraph Messaging & CDC Tier
        KafkaBroker[(Kafka KRaft:9092)]
        KafkaUI[Kafka UI:8090]
        DebeziumConnect[Debezium CDC:8083]
    end

    subgraph Monitoring Tier
        Prometheus[Prometheus:9090]
        Grafana[Grafana:3000]
        Jaeger[Jaeger UI:16686]
    end

    OrderSvc --- OrderDB
    InvSvc --- InvDB
    PaySvc --- PayDB
    CartSvc --- Redis
    InvSvc --- Redis

    Core Application Containers <--> KafkaBroker
    DebeziumConnect --> KafkaBroker
    OrderDB -.->|WAL CDC| DebeziumConnect
    InvDB -.->|WAL CDC| DebeziumConnect
```

---

## 2. DOCKER COMPOSE ORCHESTRATION PROFILE (LOCAL INFRASTRUCTURE)

Dưới đây là tệp cấu hình triển khai toàn bộ hạ tầng cơ bản (Infrastructure Backbone) phục vụ cho quá trình phát triển và kiểm thử:

```yaml
version: '3.8'

networks:
  commerceflow-net:
    driver: bridge

volumes:
  postgres-order-data:
  postgres-inv-data:
  postgres-pay-data:
  kafka-data:
  redis-data:

services:
  # ---------------------------------------------
  # KAFKA (KRAFT MODE - NO ZOOKEEPER NEEDED)
  # ---------------------------------------------
  kafka:
    image: confluentinc/cp-kafka:7.6.0
    container_name: commerceflow-kafka
    networks:
      - commerceflow-net
    ports:
      - "9092:9092"
      - "29092:29092"
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: 'CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT'
      KAFKA_ADVERTISED_LISTENERS: 'PLAINTEXT://kafka:29092,PLAINTEXT_HOST://localhost:9092'
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
      KAFKA_PROCESS_ROLES: 'broker,controller'
      KAFKA_CONTROLLER_QUORUM_VOTERS: '1@kafka:29093'
      KAFKA_LISTENERS: 'PLAINTEXT://0.0.0.0:29092,CONTROLLER://0.0.0.0:29093,PLAINTEXT_HOST://0.0.0.0:9092'
      KAFKA_INTER_BROKER_LISTENER_NAME: 'PLAINTEXT'
      KAFKA_CONTROLLER_LISTENER_NAMES: 'CONTROLLER'
      KAFKA_LOG_DIRS: '/tmp/kraft-combined-logs'
      CLUSTER_ID: 'MkU3OEVBNTcwNTJENDM2Qk'
    volumes:
      - kafka-data:/tmp/kraft-combined-logs

  # ---------------------------------------------
  # KAFKA UI (MANAGEMENT DASHBOARD)
  # ---------------------------------------------
  kafka-ui:
    image: provectuslabs/kafka-ui:v0.7.2
    container_name: commerceflow-kafka-ui
    networks:
      - commerceflow-net
    ports:
      - "8090:8080"
    environment:
      KAFKA_CLUSTERS_0_NAME: local-cluster
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:29092
    depends_on:
      - kafka

  # ---------------------------------------------
  # REDIS (DISTRIBUTED LOCK & FLASH SALE CACHE)
  # ---------------------------------------------
  redis:
    image: redis:7.2-alpine
    container_name: commerceflow-redis
    networks:
      - commerceflow-net
    ports:
      - "6379:6379"
    command: ["redis-server", "--appendonly", "yes"]
    volumes:
      - redis-data:/data

  # ---------------------------------------------
  # POSTGRESQL INSTANCES (DATABASE PER SERVICE)
  # ---------------------------------------------
  postgres-order:
    image: postgres:16-alpine
    container_name: commerceflow-postgres-order
    networks:
      - commerceflow-net
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: commerceflow_order_db
      POSTGRES_USER: order_user
      POSTGRES_PASSWORD: order_secure_password
    volumes:
      - postgres-order-data:/var/lib/postgresql/data

  postgres-inventory:
    image: postgres:16-alpine
    container_name: commerceflow-postgres-inv
    networks:
      - commerceflow-net
    ports:
      - "5433:5432"
    environment:
      POSTGRES_DB: commerceflow_inventory_db
      POSTGRES_USER: inv_user
      POSTGRES_PASSWORD: inv_secure_password
    volumes:
      - postgres-inv-data:/var/lib/postgresql/data

  postgres-payment:
    image: postgres:16-alpine
    container_name: commerceflow-postgres-pay
    networks:
      - commerceflow-net
    ports:
      - "5434:5432"
    environment:
      POSTGRES_DB: commerceflow_payment_db
      POSTGRES_USER: pay_user
      POSTGRES_PASSWORD: pay_secure_password
    volumes:
      - postgres-pay-data:/var/lib/postgresql/data

  # ---------------------------------------------
  # OBSERVABILITY (JAEGER & PROMETHEUS)
  # ---------------------------------------------
  jaeger:
    image: jaegertracing/all-in-one:1.55
    container_name: commerceflow-jaeger
    networks:
      - commerceflow-net
    ports:
      - "16686:16686" # UI
      - "4317:4317"   # OTLP gRPC
      - "4318:4318"   # OTLP HTTP

  prometheus:
    image: prom/prometheus:v2.51.0
    container_name: commerceflow-prometheus
    networks:
      - commerceflow-net
    ports:
      - "9090:9090"
    volumes:
      - ./infra/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana:10.4.0
    container_name: commerceflow-grafana
    networks:
      - commerceflow-net
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    depends_on:
      - prometheus
```

---

## 3. ĐỊNH HƯỚNG MÔ HÌNH PRODUCTION TRÊN KUBERNETES (K8S TARGET TOPOLOGY)

1. **Ingress Controller**: AWS ALB / NGINX Ingress Controller xử lý SSL Termination (TLS 1.3), chặn DDoS cơ bản và chuyển tiếp vào `api-gateway` Pods.
2. **Horizontal Pod Autoscaler (HPA)**:
   - Các Spring Boot stateless microservices (`order-service`, `inventory-service`, `cart-service`) được cấu hình HPA scale tự động từ 3 đến 20 replicas dựa trên chỉ số CPU (> 65%) hoặc Custom Prometheus Metric (HTTP Request Rate).
3. **Stateful Resources**:
   - PostgreSQL: Triển khai cụm HA thông qua Cloud-native PG Operator (Crunchy Data hoặc Zalando Postgres Operator) với 1 Primary (Read/Write) và 2 Standbys (Read Replica & Failover tự động).
   - Kafka: Triển khai bằng **Strimzi Kafka Operator**, quản trị Kafka Cluster trên K8s với Persistent Volumes trên NVMe SSD tốc độ cao.
