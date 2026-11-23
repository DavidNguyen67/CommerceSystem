# THIẾT KẾ CHI TIẾT CÁC MICROSERVICES (MICROSERVICES ARCHITECTURE DESIGN)
**Hệ thống:** CommerceFlow Enterprise Multi-vendor Marketplace  
**Kiến trúc:** Bounded Contexts & Database-per-Service  
**Phiên bản:** 2.0.0 (Comprehensive Shopee-Grade Specification)  

---

## 1. DANH SÁCH & BẢN ĐỒ DỊCH VỤ (MICROSERVICES ROSTER)

### 1.1. Tầng Edge & Gateway (Edge & Security Tier)
* `gateway-service` (Spring Cloud Gateway): Cửa ngõ duy nhất đón nhận toàn bộ HTTP request từ Web/Mobile Client; thực thi **Redis Token Bucket Rate Limiting** (theo User ID và Client IP), kiểm tra bảo mật, xử lý CORS và phân phối định tuyến (Routing & Reverse Proxy) tới các microservice nội bộ.

### 1.2. Tầng Core Microservices (Database per Service)
Hệ thống nghiệp vụ lõi gồm 12 dịch vụ độc lập:
1. `identity-service`: Quản lý xác thực, cấp phát JWT và phân quyền (RBAC: Customer, Seller, Admin).
2. `customer-service`: Quản lý hồ sơ cá nhân khách hàng, sổ địa chỉ nhận hàng, phân hạng Loyalty.
3. `seller-service`: Quản lý hồ sơ gian hàng, danh mục riêng của shop, thiết lập kho lấy hàng và kho trả hàng.
4. `product-service`: Quản lý cây danh mục sàn, thương hiệu, sản phẩm gốc (SPU), biến thể (SKU) và thư viện ảnh/video trưng bày.
5. `cart-service`: Quản lý giỏ hàng phân cụm theo Seller trên Redis In-Memory Store (TTL 30 ngày, phản hồi < 5ms).
6. `inventory-service`: Quản lý tồn kho vật lý và khả dụng của từng SKU, khóa kho tạm thời (Reservations), chống bán vượt (Anti-Overselling).
7. `order-service`: Tiếp nhận checkout, tạo Parent Order và phân tách Sub-Orders theo từng Seller, lưu vết lịch sử đơn hàng.
8. `order-orchestrator-service`: Điều phối tiến trình Saga phân tán cho Checkout, Hủy đơn và Hoàn tiền.
9. `payment-service`: Quản lý giao dịch cổng thanh toán, tài khoản ký quỹ sàn giữ tiền người bán (Escrow Ledger) và quy trình hoàn tiền.
10. `promotion-service`: Quản lý Chiến dịch Campaign, khung giờ Flash Sale, Voucher sàn và Voucher riêng của Shop.
11. `shipping-service`: Tính cước vận chuyển động, tích hợp API đơn vị vận chuyển (SPX, GHN, GHTK), sinh mã vận đơn và cập nhật hành trình.
12. `review-service`: Quản lý đánh giá 1-5 sao sau mua hàng, hình ảnh/video feedback, phản hồi của Shop và thưởng Shopee Xu.
*(Notification Service hoạt động như một generic consumer đẩy Email, SMS và Push Notification)*.

---

## 2. ĐẶC TẢ CHI TIẾT TỪNG MICROSERVICE

### 2.1. Product Catalog Service (`product-service`)
- **Trách nhiệm**: Quản lý toàn bộ thông tin trưng bày hàng hóa, cây danh mục ngành hàng đa cấp, thông tin thương hiệu, sản phẩm gốc (SPU), bộ sưu tập hình ảnh, thuộc tính phân loại (Options) và ma trận biến thể bán hàng (SKUs).
- **Dữ liệu sở hữu**: `categories`, `brands`, `products`, `product_images`, `product_options`, `product_option_values`, `product_skus`, `sku_option_combinations`.
- **Cache**: Redis Key-Value lưu thông tin chi tiết SPU + SKUs phục vụ truy vấn đọc thông lượng cao.
- **APIs công khai**:
  - `GET /api/v1/categories`: Lấy cây danh mục sàn.
  - `GET /api/v1/products`: Tìm kiếm, lọc sản phẩm trưng bày.
  - `GET /api/v1/products/{slug}`: Chi tiết SPU và danh sách biến thể.
  - `POST /api/v1/seller/products`: Seller đăng bán sản phẩm mới.
  - `PUT /api/v1/seller/products/{id}`: Seller cập nhật sản phẩm.
- **Kafka Topics**:
  - *Produced*: `product.events` (`ProductCreatedEvent`, `ProductPriceChangedEvent`, `ProductStatusUpdatedEvent`).
  - *Consumed*: `review.events` (để cập nhật `rating_average` và `rating_count` cho SPU).

---

### 2.2. Seller & Shop Service (`seller-service`)
- **Trách nhiệm**: Quản lý vòng đời gian hàng người bán, thông tin nhận diện thương hiệu shop, thiết lập kho lấy hàng (`PICKUP`) và kho trả hàng (`RETURN`), danh mục trưng bày riêng của shop.
- **Dữ liệu sở hữu**: `shops`, `seller_addresses`, `shop_categories`.
- **APIs công khai**:
  - `GET /api/v1/shops/{shopId}`: Xem trang chủ công khai của Shop.
  - `GET /api/v1/seller/shop/profile`: Quản lý thông tin gian hàng.
  - `POST /api/v1/seller/addresses`: Cấu hình kho lấy/trả hàng.
  - `POST /api/v1/seller/shop-categories`: Tạo danh mục riêng của shop.
- **Kafka Topics**:
  - *Consumed*: `review.events` (cập nhật đánh giá sao trung bình của Shop).

---

### 2.3. Customer Service (`customer-service`)
- **Trách nhiệm**: Quản lý thông tin người mua hàng, sổ địa chỉ nhận hàng có lưu tọa độ GPS, tích lũy điểm thưởng loyalty (Shopee Xu) và phân hạng thành viên.
- **Dữ liệu sở hữu**: `customer_profiles`, `customer_addresses`.
- **APIs công khai**:
  - `GET /api/v1/customer/profile`: Xem hồ sơ và số dư xu.
  - `GET /api/v1/customer/addresses`: Lấy danh sách sổ địa chỉ nhận hàng.
  - `POST /api/v1/customer/addresses`: Thêm địa chỉ nhận hàng mới.
- **Kafka Topics**:
  - *Consumed*: `review.events` (tự động cộng xu khi khách review có kèm ảnh/video), `order.events` (tính điểm chi tiêu loyalty khi đơn hoàn thành).

---

### 2.4. Order Service (`order-service`)
- **Trách nhiệm**: Tiếp nhận đơn hàng, quản lý vòng đời Parent Order và Sub-Orders, lưu vết snapshot giá và địa chỉ tại thời điểm mua, hỗ trợ tra cứu đơn cho Customer và Seller.
- **Dữ liệu sở hữu**: `parent_orders`, `sub_orders`, `order_items`, `order_outbox`, `order_inbox`.
- **APIs công khai**:
  - `POST /api/v1/orders/checkout`: Khởi tạo đơn hàng từ giỏ hàng.
  - `GET /api/v1/orders/{id}`: Tra cứu chi tiết đơn hàng (kèm phân quyền).
  - `POST /api/v1/orders/{id}/cancel`: Yêu cầu hủy đơn hàng.
  - `GET /api/v1/seller/orders`: Lấy danh sách sub-orders theo Seller ID.
  - `POST /api/v1/seller/orders/{subOrderId}/pack`: Seller bấm đóng gói và yêu cầu lấy hàng.
- **Kafka Topics**:
  - *Produced*: `order.checkout.initiated`, `order.cancelled`, `order.status.updated`.
  - *Consumed*: `order.commands` (từ Orchestrator: `UpdateOrderStatusCommand`, `ConfirmOrderCommand`, `RejectOrderCommand`), `shipping.events` (cập nhật trạng thái `DELIVERED`).

---

### 2.5. Order Orchestrator Service (`order-orchestrator-service`)
- **Trách nhiệm**: Quản lý State Machine của các tiến trình Saga phân tán, lưu vết bước thực thi, điều phối gửi lệnh (Commands) và lắng nghe sự kiện (Events), kích hoạt luồng bù trừ khi có lỗi.
- **Dữ liệu sở hữu**: `saga_instances`, `saga_step_executions`, `saga_outbox`.
- **APIs nội bộ**: `GET /internal/sagas/{orderId}` (Tra cứu tiến độ Saga cho monitoring).
- **Kafka Topics**:
  - *Consumed*: `order.checkout.initiated`, `inventory.events`, `promotion.events`, `payment.events`.
  - *Produced*: `inventory.commands`, `promotion.commands`, `payment.commands`, `order.commands`.

---

### 2.6. Inventory Service (`inventory-service`)
- **Trách nhiệm**: Quản lý tồn kho vật lý và tồn kho khả dụng của từng SKU, thực thi khóa tạm thời (Reservation), trừ kho thực tế (Commit), hoàn kho (Release) và chống bán vượt (Anti-Overselling).
- **Dữ liệu sở hữu**: `inventories`, `inventory_reservations`, `inventory_audit_logs`, `inventory_inbox`, `inventory_outbox`.
- **Cache**: Redis Hash lưu trữ `stock:available:{skuId}` để tối ưu kiểm tra nhanh cho Flash Sale.
- **Kafka Topics**:
  - *Consumed*: `inventory.commands` (`ReserveInventoryCommand`, `CommitInventoryCommand`, `ReleaseInventoryCommand`), `product.events` (`ProductCreatedEvent` để khởi tạo bản ghi kho cho SKU mới).
  - *Produced*: `inventory.events` (`InventoryReservedEvent`, `InventoryReservationFailedEvent`, `InventoryCommittedEvent`, `InventoryReleasedEvent`).

---

### 2.7. Payment Service (`payment-service`)
- **Trách nhiệm**: Quản lý giao dịch thanh toán, tiếp nhận Webhook ngân hàng/cổng thanh toán, quản lý tài khoản ký quỹ (Escrow Ledger), xử lý giải ngân cho Seller và hoàn tiền cho Buyer.
- **Dữ liệu sở hữu**: `payment_transactions`, `escrow_ledgers`, `payment_refunds`, `payment_inbox`, `payment_outbox`.
- **APIs công khai**:
  - `POST /api/v1/payments/initiate`: Khởi tạo giao dịch thanh toán.
  - `POST /api/v1/payments/webhook`: Tiếp nhận callback từ Mock Payment Provider (xác thực HMAC).
- **Kafka Topics**:
  - *Consumed*: `payment.commands` (`InitiatePaymentCommand`, `RefundPaymentCommand`), `shipping.events` (`ShipmentDeliveredEvent` kích hoạt đếm lùi thời hạn giải ngân Escrow).
  - *Produced*: `payment.events` (`PaymentCapturedEvent`, `PaymentFailedEvent`, `PaymentRefundedEvent`).

---

### 2.8. Promotion & Flash Sale Service (`promotion-service`)
- **Trách nhiệm**: Quản lý Chiến dịch Campaign, danh mục mã giảm giá (Vouchers toàn sàn và của Shop), khung giờ Flash Sale, kiểm tra điều kiện hợp lệ và khóa lượt dùng.
- **Dữ liệu sở hữu**: `campaigns`, `vouchers`, `voucher_conditions`, `voucher_redemptions`, `flash_sales`, `flash_sale_items`, `promotion_inbox`, `promotion_outbox`.
- **APIs công khai**:
  - `GET /api/v1/promotions/vouchers`: Tra cứu danh sách voucher khả dụng.
  - `GET /api/v1/promotions/flash-sales/current`: Lấy danh sách sản phẩm Flash Sale theo khung giờ.
- **Kafka Topics**:
  - *Consumed*: `promotion.commands` (`ReserveVoucherCommand`, `RedeemVoucherCommand`, `ReleaseVoucherCommand`).
  - *Produced*: `promotion.events` (`VoucherReservedEvent`, `VoucherReservationFailedEvent`, `VoucherRedeemedEvent`).

---

### 2.9. Shipping & Logistics Service (`shipping-service`)
- **Trách nhiệm**: Tính phí vận chuyển theo khoảng cách/trọng lượng, tạo vận đơn với đối tác vận chuyển (SPX, GHN, GHTK), nhận cập nhật trạng thái lộ trình giao hàng qua Webhook.
- **Dữ liệu sở hữu**: `shipping_carriers`, `shipping_rates`, `shipments`, `shipment_tracking_events`, `shipping_inbox`, `shipping_outbox`.
- **APIs công khai**:
  - `POST /api/v1/shipping/estimate-fee`: Ước tính cước phí vận chuyển.
  - `GET /api/v1/shipping/track/{waybillNumber}`: Tra cứu lộ trình vận đơn.
  - `POST /api/v1/shipping/mock-provider/update-status`: Webhook cập nhật hành trình từ 3PL.
- **Kafka Topics**:
  - *Consumed*: `order.events` (`OrderConfirmedEvent` để tự động tạo vận đơn).
  - *Produced*: `shipping.events` (`ShipmentCreatedEvent`, `ShipmentStatusUpdatedEvent`, `ShipmentDeliveredEvent`).

---

### 2.10. Product Review & Feedback Service (`review-service`)
- **Trách nhiệm**: Tiếp nhận và quản lý đánh giá sao 1-5 sao, nhận xét văn bản, ảnh và video feedback của khách hàng sau khi nhận hàng thành công; quản lý phản hồi của Shop.
- **Dữ liệu sở hữu**: `product_reviews`, `review_media`, `review_replies`, `review_inbox`, `review_outbox`.
- **APIs công khai**:
  - `POST /api/v1/reviews`: Khách hàng gửi đánh giá sản phẩm.
  - `GET /api/v1/products/{productId}/reviews`: Xem danh sách đánh giá của sản phẩm.
  - `POST /api/v1/seller/reviews/{reviewId}/reply`: Người bán gửi phản hồi đánh giá.
- **Kafka Topics**:
  - *Produced*: `review.events` (`ReviewSubmittedEvent`).

---

### 2.11. Cart Service (`cart-service`)
- **Trách nhiệm**: Quản lý giỏ hàng tạm thời của khách hàng, tự động phân cụm hàng theo Seller, cập nhật số lượng và tổng tiền tạm tính.
- **Dữ liệu sở hữu**: Redis Hash `cart:{customerId}` với TTL tự gia hạn (30 ngày). Không lưu trữ quan hệ để đạt tốc độ phản hồi < 5ms.
- **APIs công khai**: `GET /api/v1/cart`, `POST /api/v1/cart/items`, `PUT /api/v1/cart/items/{skuId}`, `DELETE /api/v1/cart/items/{skuId}`.

---

### 2.12. Identity & Auth Service (`identity-service`)
- **Trách nhiệm**: Xác thực tài khoản người dùng, cấp phát JWT Bearer Token, làm mới token (Refresh Token), phân quyền theo Role (`CUSTOMER`, `SELLER`, `ADMIN`).
- **Dữ liệu sở hữu**: `users` table tại `commerceflow_customer_db`.
- **APIs công khai**: `POST /api/v1/auth/register`, `POST /api/v1/auth/login`, `POST /api/v1/auth/refresh`.

---

### 2.13. Background Job & Scheduler Service (`job-service`)
- **Công nghệ lõi**: Spring Boot 3.x/4.x + **Quartz Scheduler** (`spring-boot-starter-quartz`).
- **Trách nhiệm**: Thực thi các tác vụ định kỳ (Cron / Scheduled Jobs) và dọn dẹp hệ thống không đồng bộ:
  - **Order Expiration TTL (BR-ORD-005)**: Quét các đơn hàng `PENDING_PAYMENT` quá hạn 15 phút (hoặc 3 phút Flash Sale) để phát lệnh hủy đơn và hoàn trả tồn kho.
  - **Payment Reconciliation**: Đối soát định kỳ trạng thái giao dịch ngân hàng/cổng thanh toán để bù đắp các trường hợp webhook bị rớt.
  - **Escrow Auto-Release**: Quét giải ngân tiền ký quỹ cho Shop sau khi đơn hàng kết thúc thời hạn khiếu nại (3 - 7 ngày).
  - **Transactional Outbox/Inbox Housekeeping (ADR-002)**: Định kỳ xóa các bản ghi outbox/inbox đã dispatch/process thành công.
  - **Saga Crash Recovery**: Quét các Saga Instance bị treo do container restart để tiếp tục điều phối hoặc bồi hoàn (Rollback).
- **Phối hợp hạ tầng**: Sử dụng ShedLock (Redis distributed lock) để đảm bảo an toàn đơn nhiệm (Single Execution) khi scale nhiều replica.

