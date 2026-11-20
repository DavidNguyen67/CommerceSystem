# ADR-004: QUẢN LÝ VÒNG ĐỜI TỒN KHO HAI PHA (TWO-PHASE STOCK RESERVATION)
**Trạng thái:** ACCEPTED  
**Ngày quyết định:** 2026-11-19  

---

## 1. BỐI CẢNH (CONTEXT)
Nếu khấu trừ trực tiếp tồn kho vật lý (`physical_quantity = physical_quantity - 1`) ngay khi khách vừa bấm đặt hàng, khi khách hàng không thanh toán hoặc hủy đơn sau 15 phút, tồn kho vật lý bị mất đi tạm thời khiến những khách hàng khác không thể mua được. Ngược lại, nếu không khóa hàng mà đợi đến lúc khách trả tiền xong mới kiểm tra kho, tỷ lệ thanh toán thành công nhưng không có hàng để giao sẽ tăng vọt, gây thảm họa trải nghiệm người dùng.

---

## 2. QUYẾT ĐỊNH (DECISION)
Chúng tôi quyết định triển khai mô hình **Two-Phase Inventory Lifecycle**:
- **Phase 1: Soft Reservation (Khóa tạm thời)**:
  - Khi đơn hàng vừa tạo, tăng `reserved_quantity = reserved_quantity + qty`.
  - Tồn kho khả dụng giảm: `available = physical - reserved`.
  - Tạo bản ghi `inventory_reservations` với hạn thời gian sống (`expires_at = NOW() + 15 mins`).
- **Phase 2: Hard Commitment (Khấu trừ vĩnh viễn)**:
  - Khi cổng thanh toán xác nhận giao dịch thành công, giảm cả `physical_quantity` và `reserved_quantity`. Chuyển trạng thái reservation sang `COMMITTED`.
- **Hoàn trả (Rollback)**:
  - Nếu quá hạn hoặc hủy đơn: Giảm `reserved_quantity`, chuyển reservation sang `RELEASED`.

---

## 3. HỆ QUẢ (CONSEQUENCES)
- **Tích cực**: Bảo vệ kho hàng không bị âm; không bán vượt; người mua có 15 phút an tâm thanh toán mà không sợ bị người khác cướp mất hàng.
- **Hạn chế**: Cần một background sweeper worker quét định kỳ các reservation bị quá hạn để tự động giải phóng tồn kho.
