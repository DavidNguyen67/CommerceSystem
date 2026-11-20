# COMMERCEFLOW — ENTERPRISE DISTRIBUTED E-COMMERCE MARKETPLACE
## BỘ TÀI LIỆU KIẾN TRÚC & ĐẶC TẢ HỆ THỐNG PHÂN TÁN TOÀN DIỆN
**Hệ thống:** CommerceFlow Multi-vendor Marketplace  
**Kiến trúc:** Microservices & Event-Driven Architecture (EDA)  
**Phiên bản:** 2.0.0 (Comprehensive Shopee-Grade Specification)  

---

### 1. TỔNG QUAN HỆ THỐNG
**CommerceFlow** là nền tảng thương mại điện tử đa người bán (Multi-vendor Marketplace) thế hệ mới theo mô hình sàn giao dịch (như Shopee, Lazada). Hệ thống được module hóa thành 11 microservices độc lập theo chuẩn Database-per-Service, kết hợp Kafka Event Backbone và Saga Orchestration để giải quyết triệt để các bài toán phân tán phức tạp:
- **Trưng bày & Phân loại hàng (Catalog & Display)**: Mô hình SPU (sản phẩm gốc) và SKU (biến thể theo màu sắc, kích cỡ), cây danh mục ngành hàng đa cấp, thư viện ảnh/video.
- **Gian hàng & Người bán (Multi-vendor Shops)**: Đăng ký shop, phân hạng Shop Yêu thích / Shopee Mall, cấu hình kho lấy hàng và kho trả hàng riêng biệt.
- **Giao dịch phân tán & Chống bán vượt (Anti-Overselling)**: Điều phối Saga Orchestration qua Kafka, áp dụng *Conditional Atomic Invariant Update* tại PostgreSQL và Redis Lua Script tại tầng Flash Sale.
- **Tách đơn tự động (Order Splitting)**: 1 Parent Order được chia thành $N$ Sub-Orders theo từng Seller để xử lý đóng gói và vận chuyển độc lập.
- **Vận chuyển & Vận đơn (Logistics & Shipments)**: Tính cước vận chuyển động theo khoảng cách/khối lượng, tích hợp API đơn vị vận chuyển (SPX, GHN, GHTK), theo dõi lộ trình thời gian thực.
- **Ký quỹ Người bán (Escrow Mechanism)**: Tự động giữ tiền thanh toán và chỉ giải ngân cho người bán sau khi đơn hàng giao thành công và kết thúc thời hạn khiếu nại.
- **Đánh giá & Khách hàng thân thiết (Reviews & Loyalty)**: Đánh giá 1-5 sao kèm ảnh/video mở hộp, tự động cộng Shopee Xu thưởng, nâng hạng thành viên.

---

### 2. CẤU TRÚC KHO TÀI LIỆU (DOCUMENTATION REPOSITORY MAP)

Hệ thống tài liệu được tổ chức theo chuẩn kiến trúc doanh nghiệp thành 17 phân mục độc lập nhưng liên kết chặt chẽ (Traceability Matrix):

```
docs/
├── 00-overview/
│   └── README.md                          # Tổng quan kiến trúc, bản đồ tài liệu và hướng dẫn
├── 01-business/
│   ├── BRD.md                             # Business Requirements Document (Tài liệu yêu cầu nghiệp vụ)
│   ├── business-rules.md                  # Ma trận quy tắc nghiệp vụ (Cross-Domain Business Rules)
│   └── use-cases.md                       # Đặc tả chi tiết các Use Cases nghiệp vụ (Customer, Seller, 3PL)
├── 02-requirements/
│   ├── SRS.md                             # Software Requirements Specification (Đặc tả yêu cầu phần mềm)
│   ├── functional-requirements.md         # Yêu cầu chức năng chi tiết 9 phân hệ (Catalog, Shop, Order...)
│   └── non-functional-requirements.md     # Yêu cầu phi chức năng (SLAs, SLOs, Concurrency, Availability)
├── 03-architecture/
│   ├── system-architecture.md             # Kiến trúc tổng thể hệ thống, Bounded Contexts, Container Diagram
│   └── saga-design.md                     # Thiết kế Saga Orchestration & Choreography chi tiết
├── 04-microservices/
│   └── microservices-design.md            # Thiết kế chi tiết 11 Microservices (Trách nhiệm, Data, APIs)
├── 05-kafka/
│   ├── kafka-architecture.md              # Kiến trúc Kafka, Partitioning, Delivery Semantics, Idempotency
│   └── event-contracts.md                 # Bộ hợp đồng dữ liệu sự kiện (CloudEvents / JSON Schema)
├── 06-api/
│   └── api-specifications.md              # Đặc tả API Gateway, Catalog, Customer, Seller, Shipping, Review
├── 07-database/
│   └── erd-and-data-models.md             # Data Models, Database Schemas, Indexes, Outbox/Inbox Tables
├── 08-sequence/
│   └── sequence-diagrams.md               # Sơ đồ tuần tự các luồng trọng yếu (Checkout, Ship, Review, Refund)
├── 09-state-machines/
│   └── state-machines.md                  # State Machines cho Order, Payment, Inventory, Shipping
├── 10-reliability/
│   ├── failure-scenario-matrix.md         # Ma trận kịch bản lỗi phân tán (Failure Scenarios Matrix)
│   └── distributed-scenarios-deep-dive.md # Phân tích chuyên sâu 12 kịch bản phân tán nâng cao
├── 11-adr/
│   ├── ADR-001-hybrid-saga-orchestration.md
│   ├── ADR-002-transactional-outbox-inbox-cdc.md
│   ├── ADR-003-parent-suborder-splitting.md
│   ├── ADR-004-two-phase-inventory-reservation.md
│   └── ADR-005-flash-sale-redis-lua-admission-control.md
├── 12-security/
│   └── security-threat-model.md           # Mô hình đe dọa STRIDE, RBAC, OAuth2/JWT & Data Isolation
├── 13-observability/
│   └── observability-strategy.md          # Chiến lược Giám sát, Distributed Tracing, Logs & Alerts
├── 14-testing/
│   └── test-strategy.md                   # Chiến lược kiểm thử, Testcontainers, Concurrency & Chaos Testing
├── 15-performance/
│   └── performance-benchmark-plan.md      # Kế hoạch đo kiểm hiệu năng, K6 Scripts, Bottleneck Analysis
└── 16-deployment/
    └── deployment-architecture.md         # Kiến trúc triển khai Docker Compose, Topology hạ tầng & CI/CD
```

---

### 3. TECH STACK & ARCHITECTURAL FOUNDATION

| Lớp kiến trúc | Công nghệ sử dụng | Mục đích kỹ thuật |
|---|---|---|
| **Core Platform** | Java 21 LTS | Sử dụng Virtual Threads (Project Loom) tối ưu I/O Concurrency |
| **Framework** | Spring Boot 3.3.x | Hệ sinh thái enterprise: Spring Data, Spring Security, Spring Kafka |
| **Message Broker** | Apache Kafka 3.7 (KRaft) | Xương sống truyền thông bất đồng bộ, phân tán phân vùng (Partitions) |
| **Primary Database** | PostgreSQL 16 | ACID Database per Service, JSONB, Conditional Atomic Updates |
| **In-Memory Cache** | Redis 7.2 (Cluster) | Catalog Cache, Shopping Cart (`cart:{customerId}`), Flash Sale Lua Scripts |
| **CDC Pipeline** | Debezium 2.6 | Change Data Capture trên Outbox Tables để đảm bảo Exactly-Once dispatch |
| **Security** | Spring Security 6 + OAuth2 Resource Server | JWT Bearer, RBAC (Customer, Seller, Admin), Data Isolation |
| **Observability** | OpenTelemetry + Jaeger + Prometheus + Grafana | Distributed Tracing, Consumer Lag monitoring, Golden Signals |
| **Integration Testing** | Testcontainers 1.20 | Chạy Kafka, PostgreSQL, Redis thật trong Unit/Integration Test suite |
| **Load Testing** | k6 | Đo kiểm áp lực Concurrency (100 $\rightarrow$ 1,000 requests đồng thời) |

---

### 4. NGUYÊN TẮC THIẾT KẾ BẤT BIẾN (ARCHITECTURAL INVARIANTS)

1. **Database-Per-Service**: Mỗi microservice sở hữu schema độc lập. Tuyệt đối không cho phép truy vấn chéo database (Cross-database query) hoặc chia sẻ connection pool.
2. **Zero Overselling Invariant**: Số lượng đặt mua thành công tại bất kỳ thời điểm nào không bao giờ được vượt quá số lượng tồn kho vật lý của SKU ($\sum \text{Reserved} + \sum \text{Deducted} \le \text{Total Inventory}$).
3. **No Direct HTTP for State Mutations**: Tất cả các cập nhật trạng thái liên dịch vụ trong luồng Checkout/Hủy/Hoàn tiền phải đi qua Saga Orchestrator và Kafka Event Bus.
4. **Idempotency Everywhere**: Mọi consumer và mọi endpoint ghi dữ liệu đều phải có cơ chế Idempotent xử lý an toàn trước các event lặp hoặc retry từ mạng.
5. **Traceability**: Mọi request từ API Gateway đều được gắn `X-Correlation-ID` và `traceparent` (W3C standard), truyền dẫn xuyên suốt qua HTTP Headers và Kafka Record Headers.

---

### 5. ÁNH XẠ TRIỂN KHAI SOURCE CODE (6-PROJECT BUNDLE MAPPING)

Để hiện thực hóa 11 microservices trên trong quá trình phát triển mã nguồn mà vẫn tối ưu tài nguyên và dễ dàng quản lý, toàn bộ hệ thống được quy hoạch thành **6 project/module** (Tham khảo chi tiết tại [README.md](../../README.md)):

1. **`common-core`** *(Java Library)*: Thư viện tiện ích dùng chung (`DateTimeUtils`, `JsonUtils`, `CurrencyUtils`, `StringUtils`, `BaseException`).
2. **`common-model`** *(Java Library)*: Hợp đồng dữ liệu (`EventEnvelope<T>`, DTOs, Enums, Saga Commands & Events).
3. **`api-service`** *(Spring Boot App)*: Điểm tiếp nhận HTTP từ Client (Order Checkout, Catalog, Cart, Webhook thanh toán).
4. **`saga-orchestrator`** *(Spring Boot App)*: Bộ não điều phối giao dịch phân tán, quản lý Saga State Machine và bù trừ (Rollback) theo ADR-001.
5. **`event-consumer`** *(Spring Boot App)*: Worker tiếp nhận sự kiện Kafka thực thi nghiệp vụ Kho (Inventory locks/commits), Vận đơn và Thông báo.
6. **`job-service`** *(Spring Boot App)*: Worker chạy tác vụ nền & định kỳ (Order Expiration TTL hủy đơn tự động, Đối soát thanh toán, Giải ngân Escrow, Dọn dẹp Outbox/Inbox).
