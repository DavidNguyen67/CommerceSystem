# ADR-005: KIỂM SOÁT TẢI FLASH SALE BẰNG IN-MEMORY REDIS LUA ADMISSION CONTROL
**Trạng thái:** ACCEPTED  
**Ngày quyết định:** 2026-11-19  

---

## 1. BỐI CẢNH (CONTEXT)
Trong các sự kiện Flash Sale (ví dụ: mở bán 50 chiếc iPhone giá 1.000đ), hệ thống phải hứng chịu hàng chục nghìn lượt request đồng thời trong vài giây. Nếu đẩy toàn bộ lượng request này trực tiếp xuống PostgreSQL (dù dùng Pessimistic hay Optimistic Lock) hoặc dồn vào Kafka partition của SKU đó, database connection pool sẽ sập hoặc Kafka gặp sự cố Hot Partition nghiêm trọng.

---

## 2. QUYẾT ĐỊNH (DECISION)
Chúng tôi quyết định áp dụng cơ chế **In-Memory Pre-Allocation & Admission Control**:
1. Trước khi Flash Sale bắt đầu, số lượng tồn kho khả dụng được nạp trước (Warm-up) vào Redis Key: `flashsale:stock:{skuId}`.
2. Tại tầng Edge/API Gateway, thực thi một đoạn **Redis Lua Script** kiểm tra và trừ tồn kho nguyên tử (`atomic DECRBY`).
3. Redis là single-threaded trong việc thực thi Lua script, do đó đảm bảo tính tuần tự tuyệt đối (Serialization) ở cấp độ micro-giây mà không cần bất kỳ lock phân tán nào.
4. Chỉ những request trừ Redis thành công (tối đa đúng 50 requests) mới được cấp `ReservationToken` và chuyển tiếp vào hệ thống xử lý nội bộ. 99.9% requests còn lại nhận phản hồi `409 OUT_OF_STOCK` ngay lập tức tại tầng mạng mà không gây ảnh hưởng đến Database hay Kafka.

---

## 3. HỆ QUẢ (CONSEQUENCES)
- **Tích cực**: Bảo vệ 100% cơ sở dữ liệu quan hệ phía sau khỏi sập tải; latency phản hồi cực nhanh (< 5ms); triệt tiêu hoàn toàn bài toán Hot Partition trên Kafka.
- **Hạn chế**: Nếu Redis node bị mất điện đột ngột mà chưa kịp đồng bộ với PostgreSQL, cần cơ chế đối soát phục hồi trạng thái từ log.
