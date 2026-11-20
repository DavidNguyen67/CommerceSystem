# ADR-002: ÁP DỤNG TRANSACTIONAL OUTBOX, INBOX PATTERN VÀ DEBEZIUM CDC
**Trạng thái:** ACCEPTED  
**Ngày quyết định:** 2026-11-19  

---

## 1. BỐI CẢNH (CONTEXT)
Khi một Microservice cần cập nhật cơ sở dữ liệu và phát sinh một sự kiện lên Apache Kafka, vấn đề **Dual-Write Inconsistency** xuất hiện:
- Nếu ghi DB trước rồi gửi Kafka: Nếu Kafka broker tạm thời bị nghẽn mạng hoặc ứng dụng bị crash trước khi gửi event, dữ liệu DB đã lưu nhưng event bị mất $\rightarrow$ Downstream services không bao giờ biết để xử lý.
- Nếu gửi Kafka trước rồi ghi DB: Nếu DB commit thất bại do vi phạm ràng buộc dữ liệu, event đã bắn đi không thể thu hồi $\rightarrow$ Phát sinh "Phantom Event" làm hỏng tính toàn vẹn hệ thống.

Đồng thời, ở phía Consumer, Kafka bảo đảm At-Least-Once delivery, đồng nghĩa với việc Consumer có thể nhận một message nhiều lần khi rebalance hoặc network glitch.

---

## 2. QUYẾT ĐỊNH (DECISION)
Chúng tôi quyết định chuẩn hóa 100% việc giao tiếp bất đồng bộ thông qua bộ ba:
1. **Transactional Outbox Pattern**: Mọi domain event được ghi trực tiếp vào bảng `outbox_events` trong cùng một Local ACID DB Transaction với dữ liệu nghiệp vụ.
2. **Debezium CDC Engine**: Debezium kết nối trực tiếp vào Write-Ahead Log (WAL) của PostgreSQL để đọc các bản ghi outbox và bắn lên Kafka với cơ chế `acks=all`, `enable.idempotence=true`.
3. **Consumer Inbox Pattern**: Mọi Consumer duy trì một bảng `consumer_inbox` lưu trữ `(message_id, consumer_group)`. Xử lý nghiệp vụ và ghi nhận inbox diễn ra trong cùng một transaction, đảm bảo tính Idempotent 100%.

---

## 3. HỆ QUẢ (CONSEQUENCES)
- **Tích cực**: Loại bỏ hoàn toàn nguy cơ mất event hoặc phát sinh event ma (Zero Data Loss). Consumer an toàn tuyệt đối trước message lặp lại.
- **Hạn chế**: Cần vận hành thêm cụm Debezium / Kafka Connect; các bảng outbox và inbox cần có job định kỳ dọn dẹp (Housekeeping) các bản ghi cũ để tránh phình to dung lượng ổ cứng.
