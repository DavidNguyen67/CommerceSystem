# ADR-003: CƠ CHẾ PHÂN TÁCH ĐƠN HÀNG PARENT ORDER VÀ SUB-ORDERS
**Trạng thái:** ACCEPTED  
**Ngày quyết định:** 2026-11-19  

---

## 1. BỐI CẢNH (CONTEXT)
CommerceFlow là sàn thương mại điện tử đa người bán. Một khách hàng có thể mua cùng lúc áo thun từ Shop A (Hà Nội) và điện thoại từ Shop B (TP. Hồ Chí Minh). Nếu chỉ tạo một bản ghi đơn hàng duy nhất, các Seller sẽ không thể tự chủ trong việc đóng gói, in vận đơn, giao cho các hãng vận chuyển khác nhau, và việc hạch toán giải ngân (Seller Payout) sẽ bị trộn lẫn không thể bóc tách.

---

## 2. QUYẾT ĐỊNH (DECISION)
Chúng tôi quyết định áp dụng cấu trúc **1 Parent Order $\rightarrow$ $N$ Sub-Orders**:
- **Parent Order**: Đại diện cho phiên giao dịch của Khách hàng, sở hữu `customerId`, tổng số tiền cần thanh toán (`total_amount`), trạng thái thanh toán tập trung (`PENDING_PAYMENT`, `CONFIRMED`, `CANCELLED`).
- **Sub-Order**: Mỗi Sub-Order thuộc về duy nhất một `sellerId`, sở hữu danh sách `order_items` của Shop đó, phí vận chuyển riêng, mã vận đơn riêng và dòng đời fulfillment độc lập (`PROCESSING`, `PACKED`, `SHIPPED`, `DELIVERED`).

---

## 3. HỆ QUẢ (CONSEQUENCES)
- **Tích cực**: Mô phỏng chính xác mô hình Shopee/Lazada; đảm bảo quyền riêng tư và tự chủ vận hành cho từng Seller; cho phép hủy hoặc khiếu nại lẻ từng gói hàng của một Shop mà không làm ảnh hưởng toàn bộ các món hàng khác đã giao thành công.
- **Hạn chế**: Tăng độ phức tạp khi phân bổ mã giảm giá toàn sàn (Platform Voucher) và phí thanh toán theo tỷ lệ phần trăm (Pro-rata).
