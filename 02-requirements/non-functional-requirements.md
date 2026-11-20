# YÊU CẦU PHI CHỨC NĂNG (NON-FUNCTIONAL REQUIREMENTS - NFR)
**Dự án:** CommerceFlow  
**Tiêu chuẩn:** ISO/IEC 25010 System Quality Model  

---

## 1. HIỆU NĂNG & THÔNG LƯỢNG (PERFORMANCE & THROUGHPUT)

| Mã NFR | Tiêu chí | Mục tiêu cam kết (SLO/Target) | Điều kiện kiểm định |
|---|---|---|---|
| **NFR-PERF-001** | API Gateway Latency | P95 < 50ms, P99 < 120ms | Dưới tải thường 1,000 req/s |
| **NFR-PERF-002** | Checkout Latency (Sync Part) | P95 < 200ms, P99 < 400ms | Tiếp nhận Checkout, tạo Parent Order và trả về payment URL |
| **NFR-PERF-003** | End-to-End Saga Latency | P95 < 1.5s, P99 < 3.0s | Từ lúc Webhook Payment thành công đến khi hoàn tất Confirm đơn & sinh vận đơn |
| **NFR-PERF-004** | Flash Sale In-Memory Concurrency | Xử lý tối thiểu 5,000 req/s trên 1 Hot SKU | Đạt kết quả thông lượng với Redis Lua script mà không gây nghẽn PostgreSQL |
| **NFR-PERF-005** | Database Connection Usage | Không vượt quá 75% connection pool size | Lúc cao điểm 1,000 concurrent checkout sessions |

---

## 2. TÍNH SẴN SÀNG & ĐỘ TIN CẬY (AVAILABILITY & FAULT TOLERANCE)

- **NFR-AVAIL-001 [High Availability Target]**: Cam kết độ sẵn sàng toàn sàn đạt **99.9%** (Downtime không vượt quá 8.76 giờ/năm).
- **NFR-AVAIL-002 [Single Point of Failure Elimination]**: Mọi microservice stateless đều triển khai tối thiểu 2 replicas. Kafka cluster chạy tối thiểu 3 brokers với `replication.factor=3`, `min.insync.replicas=2`.
- **NFR-AVAIL-003 [Zero Data Loss on Crash]**: Không làm mất mát dữ liệu tài chính hoặc dữ liệu trạng thái Saga khi một node compute bị crash. Dữ liệu outbox được bảo đảm an toàn bởi Write-Ahead Logging (WAL) của PostgreSQL.

---

## 3. TÍNH NHẤT QUÁN & TOÀN VẸN DỮ LIỆU (DATA CONSISTENCY & INTEGRITY)

- **NFR-CONS-001 [Financial & Inventory Correctness]**: **Zero Tolerance** đối với sai lệch số dư ví và bán âm tồn kho. Mọi lần chạy benchmark hay test tải, số lượng hàng bán quá mức (Overselling Violations) bắt buộc phải bằng **0**.
- **NFR-CONS-002 [Eventual Consistency Bound]**: Độ trễ đồng bộ trạng thái (Eventual Consistency Lag) giữa các Microservices qua Kafka không vượt quá **5 giây** ở điều kiện mạng bình thường.
- **NFR-CONS-003 [Consumer Idempotency Compliance]**: 100% Kafka Consumers trong hệ thống bắt buộc phải thỏa mãn tính Idempotency: Xử lý một message lặp lại $N$ lần cho ra cùng một kết quả trạng thái duy nhất.

---

## 4. AN NINH & BẢO MẬT (SECURITY & COMPLIANCE)

- **NFR-SEC-001 [Authentication & Encryption]**: Toàn bộ lưu lượng ngoại vi qua HTTPS/TLS 1.3. Xác thực bằng chuẩn OAuth2 / JWT (RS256). Mọi mật khẩu băm bằng chuẩn Argon2id hoặc BCrypt với cost factor >= 12.
- **NFR-SEC-002 [Tenant & Seller Data Isolation]**: Phân quyền RBAC nghiêm ngặt: Seller chỉ có quyền đọc/ghi dữ liệu thuộc chính Shop ID của mình (`WHERE seller_id = :currentSellerId`). Tuyệt đối không để lộ dữ liệu kinh doanh giữa các Seller (Chống lỗ hổng IDOR).
- **NFR-SEC-003 [Auditability]**: 100% các thao tác thay đổi số dư tài khoản, cập nhật tồn kho, thay đổi trạng thái đơn hàng đều phải sinh Audit Log kèm `actor_id`, `timestamp`, `old_value`, `new_value`, `ip_address`.
