# ADR-001: LỰA CHỌN MÔ HÌNH HYBRID SAGA (ORCHESTRATION KẾT HỢP CHOREOGRAPHY)
**Trạng thái:** ACCEPTED  
**Ngày quyết định:** 2026-11-19  
**Người quyết định:** Principal Architect & Senior Distributed Systems Engineer  

---

## 1. BỐI CẢNH (CONTEXT)
Trong kiến trúc Microservices với mô hình Database-per-Service, giao dịch Checkout và Thanh toán trải dài qua nhiều domain: Order, Inventory, Promotion, Payment, Shipping. Không thể sử dụng giao thức Two-Phase Commit (2PC) do nguy cơ giữ lock lâu dài gây tắc nghẽn hệ thống và tạo điểm lỗi đơn lẻ. Chúng tôi cần lựa chọn mô hình điều phối giao dịch phân tán (Saga Pattern) phù hợp.

Hai mô hình phổ biến là:
1. **Choreography (Biên đạo phi tập trung)**: Các dịch vụ phản ứng tự do theo sự kiện của nhau.
2. **Orchestration (Điều phối tập trung)**: Một dịch vụ điều phối trung tâm ra lệnh và theo dõi trạng thái.

---

## 2. QUYẾT ĐỊNH (DECISION)
Chúng tôi quyết định triển khai mô hình **Hybrid Saga**:
1. **Áp dụng Saga Orchestration (`order-orchestrator-service`)** cho luồng cốt lõi: Tiếp nhận đơn $\rightarrow$ Khóa tồn kho $\rightarrow$ Khóa voucher $\rightarrow$ Thu tiền qua Cổng thanh toán $\rightarrow$ Xác nhận đơn hoặc Bù trừ (Rollback) khi có lỗi.
2. **Áp dụng Saga Choreography** cho các luồng downstream sau khi đơn đã xác nhận thành công: `OrderConfirmed` $\rightarrow$ Shipping Service lập vận đơn, Notification Service gửi email/push.

---

## 3. HỆ QUẢ (CONSEQUENCES)

### Điểm tích cực (Positive):
- **Tránh hiện tượng Spaghetti Choreography**: Luồng bù trừ phức tạp (khi hết kho, thẻ bị từ chối, timeout) được quản lý tập trung tại một State Machine rõ ràng, dễ visualize, dễ kiểm thử và dễ truy vết lỗi.
- **Tính tự trị cao cho Downstream**: Shipping và Notification không làm nghẽn tiến trình checkout của khách hàng và có thể scale độc lập.

### Điểm hạn chế & Rủi ro (Negative & Risks):
- Tăng thêm một microservice (`order-orchestrator-service`). Nếu orchestrator bị crash, cần cơ chế phục hồi trạng thái từ PostgreSQL.

---

## 4. CÁC PHƯƠNG ÁN ĐÃ XEM XÉT (ALTERNATIVES CONSIDERED)
- **Thuần túy Choreography**: Bị bác bỏ vì luồng Checkout có quá nhiều nhánh rẽ thất bại; việc xử lý compensation dạng vòng tròn qua lại giữa các service sẽ tạo ra coupling ngầm (Cyclic Event Dependency) cực kỳ khó bảo trì.
- **Thuần túy Orchestration**: Bị bác bỏ vì việc bắt Orchestrator phải theo dõi cả trạng thái gửi email thông báo là over-engineering không cần thiết.
