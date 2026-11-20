# YÊU CẦU CHỨC NĂNG CHI TIẾT (FUNCTIONAL REQUIREMENTS - FR)
**Dự án:** CommerceFlow Enterprise Multi-vendor Marketplace  
**Kiến trúc:** Phân rã theo Microservices & Bounded Contexts  
**Phiên bản:** 2.0.0 (Comprehensive E-Commerce Specification)  

---

## 1. YÊU CẦU CHỨC NĂNG PRODUCT CATALOG & TRƯNG BÀY (FR-CAT)

- **FR-CAT-001 [Mô hình Sản phẩm SPU & Biến thể SKU]**:
  - Hệ thống phải phân tách rõ ràng giữa Sản phẩm Gốc (**SPU - Standard Product Unit**) và Biến thể Bán hàng (**SKU - Stock Keeping Unit**).
  - Một SPU có thể có $0$ hoặc nhiều nhóm phân loại (Option Groups: ví dụ Màu sắc, Kích cỡ).
  - Từng SKU là tổ hợp của các giá trị phân loại (ví dụ: Màu Đen + Size XL) và sở hữu giá niêm yết, giá bán, cân nặng, kích thước đóng gói riêng biệt.
- **FR-CAT-002 [Cây Danh mục Ngành hàng Đa cấp]**:
  - Hỗ trợ phân cấp danh mục tối thiểu 3 cấp (Ngành hàng chính $\rightarrow$ Nhóm ngành hàng $\rightarrow$ Danh mục con).
  - Một sản phẩm bắt buộc phải thuộc về một danh mục con hợp lệ.
- **FR-CAT-003 [Tìm kiếm, Lọc & Sắp xếp Trưng bày]**:
  - Khách hàng có thể tìm kiếm sản phẩm theo từ khóa tiêu đề, thương hiệu, danh mục.
  - Hỗ trợ bộ lọc động: Lọc theo khoảng giá (`minPrice`, `maxPrice`), theo đánh giá sao ($\ge 4$ sao), theo gian hàng (Shopee Mall / Shop Yêu thích).
  - Hỗ trợ các tiêu chí sắp xếp: Bán chạy nhất, Giá tăng/giảm dần, Mới nhất, Phổ biến nhất.
- **FR-CAT-004 [Đa phương tiện Trưng bày]**:
  - Hỗ trợ lưu trữ nhiều ảnh trưng bày cho sản phẩm, chỉ định 1 ảnh đại diện chính (Primary Thumbnail).
  - Cho phép gắn ảnh minh họa riêng cho từng giá trị phân loại (ví dụ: chọn phân loại Màu Trắng sẽ hiển thị ảnh sản phẩm màu trắng).

---

## 2. YÊU CẦU CHỨC NĂNG GIAN HÀNG & NGƯỜI BÁN (FR-SHOP)

- **FR-SHOP-001 [Hồ sơ Gian hàng & Phân hạng Shop]**:
  - Hỗ trợ thiết lập thông tin thương hiệu shop: Tên shop, slug đường dẫn, logo, ảnh bìa banner, mô tả giới thiệu.
  - Phân loại gian hàng theo các cấp bậc: Shop Tiêu chuẩn (`STANDARD`), Shop Yêu thích (`FAVORITE`), Gian hàng Chính hãng (`MALL`).
- **FR-SHOP-002 [Quản lý Kho Lấy hàng & Trả hàng]**:
  - Người bán phải cấu hình tối thiểu 1 địa chỉ lấy hàng (`PICKUP`) để đơn vị vận chuyển điều phối tài xế đến lấy hàng.
  - Cho phép cấu hình địa chỉ trả hàng (`RETURN`) riêng biệt khi có phát sinh khiếu nại hoàn trả.
- **FR-SHOP-003 [Danh mục Trưng bày Riêng của Shop]**:
  - Cho phép người bán tự tạo các nhóm danh mục nội bộ của shop để gom nhóm và trưng bày sản phẩm trên trang chủ gian hàng.

---

## 3. YÊU CẦU CHỨC NĂNG KHÁCH HÀNG & ĐỊNH DANH (FR-CUST)

- **FR-CUST-001 [Sổ Địa chỉ Giao hàng Đa năng]**:
  - Khách hàng có thể lưu nhiều địa chỉ nhận hàng và chỉ định 1 địa chỉ Mặc định (`is_default = true`).
  - Địa chỉ phải ghi nhận toạ độ địa lý (Latitude/Longitude) cùng cấp Tỉnh/Thành, Quận/Huyện, Phường/Xã để phục vụ tính toán cước phí và cự ly vận chuyển chính xác.
- **FR-CUST-002 [Hồ sơ & Phân hạng Thành viên Loyalty]**:
  - Tự động tích lũy điểm thưởng khi hoàn thành đơn hàng thành công hoặc đánh giá sản phẩm.
  - Nâng hạng thành viên (`BRONZE`, `SILVER`, `GOLD`, `PLATINUM`) dựa trên tổng chi tiêu tích lũy trong năm để mở khóa các đặc quyền voucher độc quyền.

---

## 4. YÊU CẦU CHỨC NĂNG ORDER & CHECKOUT (FR-ORD)

- **FR-ORD-001 [Parent-SubOrder Creation & Splitting]**:
  - Hệ thống tiếp nhận yêu cầu Checkout từ Client gồm: `customerId`, `shippingAddressId`, `paymentMethod`, `voucherCodes[]`, `items[] (skuId, quantity, sellerId, expectedPrice)`.
  - Hệ thống tự động phân nhóm danh sách `items` theo từng `sellerId` duy nhất.
  - Tạo 1 bản ghi `parent_orders` với tổng tiền thanh toán của toàn bộ giỏ hàng và $N$ bản ghi `sub_orders` tương ứng cho từng shop để xử lý đóng gói và vận chuyển độc lập.
- **FR-ORD-002 [Idempotent Checkout Handling]**:
  - Endpoint `POST /api/v1/orders/checkout` bắt buộc yêu cầu Header `Idempotency-Key: <UUID>`.
  - Nếu key đã tồn tại trong vòng 24 giờ và đơn hàng đã được tạo thành công, hệ thống phải trả về thông tin đơn hàng hiện tại kèm HTTP status `200 OK` thay vì tạo đơn hàng trùng lặp.
- **FR-ORD-003 [Order Cancellation]**:
  - Khách hàng được phép hủy đơn hàng khi đơn đang ở trạng thái `PENDING_PAYMENT` hoặc `CONFIRMED` (nếu Seller chưa chuyển trạng thái sang đóng gói/giao vận).
  - Khi hủy thành công, hệ thống phải kích hoạt luồng trả tồn kho và hoàn tiền tương ứng qua Saga Orchestrator.

---

## 5. YÊU CẦU CHỨC NĂNG QUẢN LÝ TỒN KHO (FR-INV)

- **FR-INV-001 [Stock Reservation with TTL]**:
  - Cung cấp API nội bộ / Kafka Consumer xử lý lệnh `ReserveInventoryCommand`.
  - Khóa số lượng `requestedQuantity` trên bảng `inventory_reservations` với `status = 'PENDING'` và `expires_at = NOW() + INTERVAL '15 minutes'`.
  - Tồn kho khả dụng giảm: $\text{available\_quantity} = \text{physical\_quantity} - \text{reserved\_quantity}$.
- **FR-INV-002 [Stock Commitment]**:
  - Khi nhận event `PaymentCaptured` hoặc lệnh `CommitInventoryCommand`, cập nhật trạng thái reservation sang `COMMITTED`, giảm `physical_quantity` thực tế và giảm `reserved_quantity`.
- **FR-INV-003 [Stock Release / Compensation]**:
  - Khi nhận event `OrderCancelled`, `PaymentFailed` hoặc lệnh `ReleaseInventoryCommand`, giải phóng `reserved_quantity`, chuyển trạng thái reservation sang `RELEASED`.
- **FR-INV-004 [Anti-Overselling & Invariant Update]**:
  - Tuyệt đối không cho phép tồn kho âm. Áp dụng câu lệnh Update điều kiện nguyên tử:
    `WHERE (physical_quantity - reserved_quantity) >= :qty`.

---

## 6. YÊU CẦU CHỨC NĂNG THANH TOÁN & KÝ QUỸ (FR-PAY)

- **FR-PAY-001 [Payment Initiation]**:
  - Tiếp nhận lệnh khởi tạo giao dịch thanh toán từ Order Orchestrator.
  - Tạo bản ghi `payment_transactions` với trạng thái `INITIATED`, sinh URL chuyển hướng tới Cổng thanh toán giả lập.
- **FR-PAY-002 [Webhook Ingestion & Idempotency]**:
  - Tiếp nhận Callback Webhook từ Mock Payment Provider với chữ ký HMAC.
  - Đảm bảo tính Idempotency: nếu Webhook cho cùng một `transaction_id` gửi lại nhiều lần, chỉ cập nhật DB đúng 1 lần và không phát sinh event trùng lặp.
- **FR-PAY-003 [Escrow Ledger - Ký quỹ Người bán]**:
  - Tiền thanh toán của người mua được giam giữ tại tài khoản ký quỹ trung gian của sàn (`escrow_ledgers`).
  - Chỉ tự động giải ngân cho Shop (`RELEASED_TO_SELLER`) sau khi đơn hàng chuyển sang `DELIVERED` và kết thúc thời hạn khiếu nại (ví dụ: sau 3 ngày).
- **FR-PAY-004 [Refund Processing]**:
  - Hỗ trợ hoàn tiền toàn phần (Full Refund) hoặc một phần (Partial Refund theo từng Sub-Order) khi có yêu cầu hủy/trả hàng.

---

## 7. YÊU CẦU CHỨC NĂNG KHUYẾN MÃI & FLASH SALE (FR-PRO)

- **FR-PRO-001 [Voucher Validation & Dual-tier Discounts]**:
  - Hỗ trợ áp dụng đồng thời **Voucher Toàn Sàn** (Shopee Voucher: Freeship, Hoàn xu) và **Voucher Riêng Của Shop** (Shop Voucher) trên cùng một đơn hàng.
  - Kiểm tra điều kiện: Thời gian hiệu lực, tổng lượt dùng còn lại, mức chi tiêu tối thiểu (`min_spend`), hạn mức từng người dùng.
- **FR-PRO-002 [Flash Sale Tuyến tính Khung Giờ Vàng]**:
  - Cho phép cấu hình các phiên Flash Sale theo khung giờ cố định trong ngày (0h-9h, 12h-14h, 16h-20h...).
  - Thiết lập slot số lượng bán riêng (`stock_allocated`) và giá sốc cho từng SKU.
  - Giới hạn số lượng mua tối đa cho mỗi khách hàng (`user_purchase_limit`) để chống đầu cơ.

---

## 8. YÊU CẦU CHỨC NĂNG VẬN CHUYỂN & GIAO VẬN (FR-SHIP)

- **FR-SHIP-001 [Tính Cước phí Vận chuyển Động]**:
  - Tự động tính cước vận chuyển dựa trên khoảng cách giữa Kho lấy hàng của Shop và Địa chỉ nhận hàng của Khách, kết hợp tổng trọng lượng và kích thước quy đổi của kiện hàng.
- **FR-SHIP-002 [Tạo Vận đơn Tự động (Waybill Creation)]**:
  - Ngay khi Sub-Order được xác nhận hoặc Seller bấm đóng gói, hệ thống tích hợp API đối tác vận chuyển (SPX, GHN, GHTK) để sinh mã vận đơn duy nhất (`waybill_number`).
- **FR-SHIP-003 [Cập nhật Hành trình & Webhook 3PL]**:
  - Tiếp nhận sự kiện cập nhật trạng thái lộ trình từ đối tác giao vận: `PICKED_UP` $\rightarrow$ `IN_TRANSIT` $\rightarrow$ `OUT_FOR_DELIVERY` $\rightarrow$ `DELIVERED`.
  - Lưu trữ lịch sử từng mốc thời gian và địa điểm kho trung chuyển (`shipment_tracking_events`).

---

## 9. YÊU CẦU CHỨC NĂNG ĐÁNH GIÁ & PHẢN HỒI (FR-REV)

- **FR-REV-001 [Điều kiện Đánh giá Sau Mua Hàng]**:
  - Chỉ những khách hàng đã mua và nhận hàng thành công (`DELIVERED`) mới được quyền gửi đánh giá cho từng sản phẩm trong đơn hàng.
  - Mỗi mặt hàng (`order_item_id`) chỉ được phép đánh giá một lần duy nhất.
- **FR-REV-002 [Đánh giá Đa phương tiện & Thưởng Xu]**:
  - Cho phép người dùng đánh giá 1–5 sao, viết nhận xét văn bản, đính kèm hình ảnh và video thực tế.
  - Tự động cộng thưởng điểm tích lũy / Shopee Xu vào hồ sơ khách hàng khi đánh giá có kèm hình ảnh/video hợp lệ.
- **FR-REV-003 [Phản hồi của Người bán]**:
  - Người bán nhận được thông báo khi có đánh giá mới và được phép gửi 1 phản hồi công khai cho mỗi đánh giá.
