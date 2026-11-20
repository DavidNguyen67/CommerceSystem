# MA TRẬN KỊCH BẢN SỰ CỐ PHÂN TÁN (FAILURE SCENARIO MATRIX)
**Hệ thống:** CommerceFlow Fault Tolerance Engine  
**Phiên bản:** 1.0.0  

---

## 1. MA TRẬN TỔNG HỢP 12 KỊCH BẢN SỰ CỐ PHÂN TÁN TRỌNG YẾU

| ID | Tên kịch bản | Mức độ nghiêm trọng | Rủi ro chính | Cơ chế phòng vệ cốt lõi | Thời gian phục hồi mục tiêu (MTTR) |
|---|---|---|---|---|---|
| **SC-01** | Flash Sale Overselling | **CRITICAL** | Bán âm kho, khiếu nại khách hàng diện rộng | Redis Lua Pre-allocation + DB Invariant Check | Tức thì (0ms) - Chặn tại In-memory |
| **SC-02** | Concurrent Checkout | **HIGH** | Duplicate Order, trừ tiền 2 lần cho 1 giỏ | Idempotency Key + Redis Distributed Lock + DB Unique Index | Tức thì (Từ chối request thứ 2 ngay tại Gateway) |
| **SC-03** | Payment Success - Order Crash | **CRITICAL** | Khách mất tiền nhưng đơn hàng không được ghi nhận | Payment Outbox Table + Eventual Reconciliation Poller | < 30 giây |
| **SC-04** | Cancellation During Payment | **HIGH** | Hàng bị nhả nhưng tiền vẫn bị trừ | Strict State Machine + Compensation Auto-Refund | < 5 giây |
| **SC-05** | Duplicate Kafka Events | **HIGH** | Nhân đôi số lượng đặt, trừ kho 2 lần | Consumer Inbox Pattern + DB Unique Message ID | Tức thì (Commit offset và bỏ qua logic) |
| **SC-06** | Out-of-order Events | **HIGH** | Cancel đến trước Payment Completed | State Versioning + State Transition Guard + Auto-Refund | Tức thì khi xử lý event đến sau |
| **SC-07** | Orchestrator Crash | **HIGH** | Saga bị treo giữa chừng, rò rỉ tồn kho | Persistent Saga State + Background Sweeper Job | < 60 giây |
| **SC-08** | Consumer Rebalance | **MEDIUM** | Mất offset commit, xử lý lại message dang dở | CooperativeStickyAssignor + Idempotent Processing | < 10 giây (Thời gian rebalance) |
| **SC-09** | Retry Storm & Cascading Failure | **CRITICAL** | Sập toàn bộ hệ thống do bão retry khi 3PL down | Non-blocking Retry Hierarchy + Exponential Backoff + Circuit Breaker | Tự động thích ứng theo nhịp hồi phục của 3PL |
| **SC-10** | Hot Partition Skew | **HIGH** | Tắc nghẽn 1 partition Kafka lúc Flash Sale | Admission Control tại Gateway + Key Sharding Virtual Partition | Ngăn chặn trước khi message vào Kafka |
| **SC-11** | Multi-seller Partial Stock Out | **MEDIUM** | 1 shop hết hàng làm ảnh hưởng các shop khác | All-or-Nothing Saga Rollback (Chính sách nhất quán) | < 2 giây hoàn tất bù trừ |
| **SC-12** | Return & Refund Flow | **MEDIUM** | Thất thoát tài chính khi hoàn tiền nhưng không thu hồi hàng | Escrow 7-Day Window + Two-step QC Inspection before Payout | Theo quy trình nghiệp vụ giao nhận 3PL |
