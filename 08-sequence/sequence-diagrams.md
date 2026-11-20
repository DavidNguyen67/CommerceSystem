# SƠ ĐỒ TUẦN TỰ CÁC LUỒNG TRỌNG YẾU (SEQUENCE DIAGRAMS)
**Hệ thống:** CommerceFlow Enterprise Multi-vendor Marketplace  
**Kiến trúc:** Microservices, Event-Driven & Saga Orchestration  
**Phiên bản:** 2.0.0 (Comprehensive Multi-vendor Marketplace)  

---

## 1. LUỒNG CHECKOUT & THANH TOÁN THÀNH CÔNG (HAPPY PATH)

```mermaid
sequenceDiagram
    autonumber
    actor Customer as Khách hàng
    participant GW as API Gateway
    participant OS as Order Service
    participant ORCH as Order Orchestrator
    participant IS as Inventory Service
    participant PS as Promotion Service
    participant PAY as Payment Service
    participant GW_MOCK as Mock Payment Gateway
    participant SS as Shipping Service
    participant NS as Notification Service

    Customer->>GW: POST /api/v1/orders/checkout (Idempotency-Key)
    GW->>OS: Validate Request & Idempotency Key
    OS->>OS: Insert ParentOrder & SubOrders (PENDING_VALIDATION)
    OS->>OS: Insert Outbox(OrderCheckoutInitiated)
    OS-->>Customer: Trả về orderId & Trạng thái khởi tạo

    Note over OS, ORCH: Debezium CDC bắn Event sang Kafka
    OS-)ORCH: Event: OrderCheckoutInitiated

    ORCH->>IS: Command: ReserveInventoryCommand(items)
    IS->>IS: Atomic Conditional Check & Reserve DB
    IS-->>ORCH: Event: InventoryReservedEvent

    ORCH->>PS: Command: ReserveVoucherCommand(voucherCode)
    PS->>PS: Atomic Voucher Counter Check
    PS-->>ORCH: Event: VoucherReservedEvent

    ORCH->>OS: Command: UpdateOrderStatus(PENDING_PAYMENT)
    OS->>OS: Update status = PENDING_PAYMENT
    OS-->>ORCH: Event: OrderAwaitingPaymentEvent

    Customer->>GW_MOCK: Truy cập Payment URL & Xác nhận trả tiền
    GW_MOCK->>PAY: Webhook Callback POST /api/v1/payments/webhook
    PAY->>PAY: Validate HMAC Signature & Deduplicate
    PAY->>PAY: Update PaymentTransaction(CAPTURED) + Outbox
    PAY-->>GW_MOCK: 200 OK (ACK)

    PAY-)ORCH: Event: PaymentCapturedEvent

    Note over ORCH: Tiến hành Commit giao dịch (Commit Phase)
    par Commit Song Song
        ORCH->>OS: Command: ConfirmOrderCommand
        ORCH->>IS: Command: CommitInventoryCommand
        ORCH->>PS: Command: RedeemVoucherCommand
    end

    OS->>OS: Update Order status = CONFIRMED
    IS->>IS: physical_quantity -= reserved_quantity, reserved_quantity -= reserved_quantity
    PS->>PS: voucher_usage_count += 1

    Note over OS, SS: Choreography Reaction
    OS-)SS: Event: OrderConfirmedEvent
    OS-)NS: Event: OrderConfirmedEvent

    SS->>SS: Generate Waybills & 3PL Handover
    NS->>Customer: Gửi Email / Push Thông báo đặt hàng thành công
```

---

## 2. LUỒNG THẤT BẠI DO HẾT HÀNG & BÙ TRỪ SAGA (COMPENSATION FLOW)

```mermaid
sequenceDiagram
    autonumber
    actor Customer as Khách hàng
    participant OS as Order Service
    participant ORCH as Order Orchestrator
    participant IS as Inventory Service
    participant PS as Promotion Service

    Customer->>OS: POST /api/v1/orders/checkout
    OS->>OS: Insert ParentOrder (PENDING_VALIDATION)
    OS-)ORCH: Event: OrderCheckoutInitiated

    Note over ORCH, IS: Bước 1: Khóa kho thất bại
    ORCH->>IS: Command: ReserveInventoryCommand(items)
    IS->>IS: Check Stock: available_quantity < requested_quantity
    IS-->>ORCH: Event: InventoryReservationFailedEvent(reason: OUT_OF_STOCK)

    Note over ORCH: Kích hoạt Luồng Bù trừ (Saga Compensation)
    ORCH->>OS: Command: RejectOrderCommand(orderId, REASON_OUT_OF_STOCK)
    OS->>OS: Update status = CANCELLED (Ghi rõ lý do hết hàng)
    
    Note over ORCH: Không cần bù trừ Promotion hay Payment vì chưa tới bước thực thi
    ORCH-)Customer: SSE / Push Notification: Đặt hàng thất bại do sản phẩm đã hết kho
```

---

## 3. LUỒNG WEBHOOK THANH TOÁN ĐẾN MUỘN SAU KHI ĐƠN HẾT HẠN (LATE PAYMENT & AUTO-REFUND)

```mermaid
sequenceDiagram
    autonumber
    actor Customer as Khách hàng
    participant OS as Order Service
    participant ORCH as Order Orchestrator
    participant IS as Inventory Service
    participant PAY as Payment Service
    participant GW_MOCK as Mock Payment Gateway

    Note over Customer, OS: Đơn hàng ở trạng thái PENDING_PAYMENT quá 15 phút
    ORCH->>ORCH: Timeout Sweeper phát hiện Expired
    ORCH->>IS: Command: ReleaseInventoryCommand
    IS->>IS: Hoàn trả reserved_quantity về available
    ORCH->>OS: Command: ExpireOrderCommand
    OS->>OS: Update status = EXPIRED

    Note over Customer, PAY: Khách hàng chuyển tiền trễ tại phút thứ 16
    GW_MOCK->>PAY: Webhook Callback Payment Succeeded
    PAY->>PAY: Insert PaymentTransaction(status: CAPTURED)
    PAY-)ORCH: Event: PaymentCapturedEvent

    ORCH->>OS: Query Order Status
    OS-->>ORCH: Order status is EXPIRED!

    Note over ORCH, PAY: Kích hoạt Auto-Refund Bảo vệ Khách hàng
    ORCH->>PAY: Command: InitiateAutoRefundCommand(orderId, amount, reason: LATE_PAYMENT)
    PAY->>GW_MOCK: Call Gateway API: POST /refund
    GW_MOCK-->>PAY: Refund Succeeded
    PAY->>PAY: Update status = REFUNDED
    PAY-)ORCH: Event: PaymentRefundedEvent
    ORCH->>OS: Command: UpdateOrderStatus(REFUNDED)
```

---

## 4. LUỒNG TRƯNG BÀY SẢN PHẨM & TƯƠNG TÁC BIẾN THỂ (CATALOG DISPLAY & SKU SELECTION)

```mermaid
sequenceDiagram
    autonumber
    actor Customer as Khách hàng
    participant GW as API Gateway
    participant PROD as Product Service
    participant REDIS as Redis Cache
    participant INV as Inventory Service

    Customer->>GW: GET /api/v1/products/apple-iphone-15-pro-vna
    GW->>REDIS: GET product:detail:apple-iphone-15-pro-vna
    alt Cache Hit (Phản hồi < 5ms)
        REDIS-->>GW: Trả về Cache JSON (SPU + Options + SKUs)
    else Cache Miss
        GW->>PROD: Query DB categories, brands, products, options, skus
        PROD->>REDIS: SET product:detail:... TTL = 3600s
        PROD-->>GW: Trả về Product Data
    end
    GW-->>Customer: Hiển thị Thư viện ảnh, mô tả, các nút phân loại Màu & Size

    Customer->>Customer: Bấm chọn "Màu Đen" + "Dung lượng 128GB"
    Customer->>GW: GET /api/v1/inventory/skus/SKU-IP15P-BLACK-128GB/stock
    GW->>INV: Query tồn kho khả dụng hiện hành
    INV-->>GW: availableQuantity = 45
    GW-->>Customer: Cập nhật giá 24.990.000đ, hiển thị "Còn 45 sản phẩm", nút Mua kích hoạt
```

---

## 5. LUỒNG GIAO HÀNG, ĐÁNH GIÁ SẢN PHẨM & GIẢI NGÂN KÝ QUỸ (DELIVERY, REVIEW & ESCROW)

```mermaid
sequenceDiagram
    autonumber
    actor 3PL as Đơn vị Giao vận 3PL
    participant SS as Shipping Service
    participant OS as Order Service
    participant PAY as Payment Service
    actor Customer as Khách hàng
    participant REV as Review Service
    participant CUST as Customer Service
    actor Seller as Người bán

    3PL->>SS: Webhook POST /shipping/mock-provider/update-status (status: DELIVERED)
    SS->>SS: Ghi nhận event vào shipment_tracking_events
    SS-)OS: Kafka Event: ShipmentDeliveredEvent

    OS->>OS: Update Sub-Order status = DELIVERED
    OS-)PAY: Kafka Event: OrderDeliveredForEscrow
    PAY->>PAY: Khởi tạo đếm lùi thời hạn Ký quỹ (Release due in 3 days)

    Note over Customer, REV: Khách nhận hàng ưng ý và gửi Đánh giá
    Customer->>REV: POST /api/v1/reviews (5 sao, 2 ảnh, 1 video)
    REV->>REV: Lưu product_reviews & review_media
    REV-)CUST: Kafka Event: ReviewSubmittedEvent(hasMedia: true)
    CUST->>CUST: Tự động cộng 200 Điểm thưởng Loyalty / Shopee Xu
    REV-->>Customer: Đánh giá thành công & Nhận 200 Xu

    REV-)Seller: Thông báo Đánh giá mới
    Seller->>REV: POST /api/v1/seller/reviews/{id}/reply (Gửi lời cảm ơn)

    Note over PAY: Sau 3 ngày không có khiếu nại trả hàng
    PAY->>PAY: Escrow Sweeper: Release Escrow Payout
    PAY->>PAY: Update escrow_ledgers status = RELEASED_TO_SELLER
    PAY-)Seller: Số dư Ví Người Bán được cộng tiền thành công
```
