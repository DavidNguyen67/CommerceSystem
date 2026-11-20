# HỢP ĐỒNG DỮ LIỆU SỰ KIỆN (EVENT CONTRACTS & SCHEMAS)
**Hệ thống:** CommerceFlow Event Backbone  
**Định dạng:** JSON Schema v7 / CloudEvents Compliant  
**Phiên bản:** 2.0.0 (Comprehensive Multi-vendor Marketplace)  

---

## 1. CHUẨN ĐÓNG GÓI SỰ KIỆN (STANDARD EVENT ENVELOPE)

Mọi message phát tán trên Kafka cluster bắt buộc phải tuân thủ cấu trúc phong bì tiêu chuẩn (Standard Envelope) để đảm bảo khả năng truy vết phân tán (Distributed Tracing) và tương thích mở rộng (Schema Evolution):

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["eventId", "eventType", "timestamp", "correlationId", "sourceService", "version", "payload"],
  "properties": {
    "eventId": { "type": "string", "format": "uuid" },
    "eventType": { "type": "string" },
    "timestamp": { "type": "string", "format": "date-time" },
    "correlationId": { "type": "string", "format": "uuid" },
    "causationId": { "type": "string", "format": "uuid" },
    "sourceService": { "type": "string" },
    "version": { "type": "integer", "minimum": 1 },
    "payload": { "type": "object" }
  }
}
```

---

## 2. CÁC HỢP ĐỒNG SỰ KIỆN TRỌNG YẾU (CORE EVENT SCHEMAS)

### 2.1. `OrderCheckoutInitiatedEvent`
- **Topic**: `order.checkout.initiated`
- **Partition Key**: `customerId`
- **Payload**:
```json
{
  "orderId": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "customerId": "c71a39d8-912f-410a-b28e-5b1239c81190",
  "totalAmount": 24990000,
  "discountAmount": 100000,
  "shippingFee": 50000,
  "grandTotal": 24940000,
  "currency": "VND",
  "paymentMethod": "MOCK_PAYMENT_GATEWAY",
  "appliedVouchers": [
    { "voucherCode": "FREESHIP50", "type": "SHIPPING" },
    { "voucherCode": "TECHSALE100", "type": "PLATFORM" }
  ],
  "subOrders": [
    {
      "subOrderId": "f12c98a1-1234-4567-89ab-cdef01234567",
      "sellerId": "s88a10b2-4433-2211-aa99-1234567890ab",
      "items": [
        {
          "skuId": "SKU-IP15P-BLACK-128GB",
          "quantity": 1,
          "unitPrice": 24990000
        }
      ],
      "shippingFee": 50000
    }
  ]
}
```

---

### 2.2. `ReserveInventoryCommand` & `InventoryReservedEvent`
- **Command Topic**: `inventory.commands` (Key: `skuId`)
- **Event Topic**: `inventory.events` (Key: `orderId`)
- **Command Payload**:
```json
{
  "orderId": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "reservationId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "ttlSeconds": 900,
  "items": [
    { "skuId": "SKU-IP15P-BLACK-128GB", "quantity": 1 }
  ]
}
```
- **Event Payload**:
```json
{
  "orderId": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "reservationId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "status": "RESERVED",
  "expiresAt": "2026-11-20T16:25:00Z"
}
```

---

### 2.3. `PaymentCapturedEvent`
- **Topic**: `payment.events`
- **Partition Key**: `orderId`
- **Payload**:
```json
{
  "orderId": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "paymentId": "pay-88291a2-3341",
  "gatewayTransactionId": "MOCK-BANK-TX-998822",
  "amount": 24940000,
  "currency": "VND",
  "paymentStatus": "CAPTURED",
  "paidAt": "2026-11-20T16:10:15Z"
}
```

---

### 2.4. `ProductCreatedEvent` (Catalog & Display Sync)
- **Topic**: `product.events`
- **Partition Key**: `productId`
- **Mục đích**: Đồng bộ thông tin SPU/SKU sang Elasticsearch/Search Service và khởi tạo bản ghi tồn kho bên `inventory-service`.
- **Payload**:
```json
{
  "productId": "p9922-3344-5566",
  "shopId": "s88a10b2-4433-2211-aa99-1234567890ab",
  "categoryId": "c1a2b3c4-0003-4000-8000-000000000003",
  "name": "Áo Thun Nam Thể Thao Pro-Dry",
  "slug": "ao-thun-nam-the-thao-pro-dry",
  "skus": [
    {
      "skuId": "SKU-TSHIRT-BLK-M",
      "skuName": "Áo Thun Pro-Dry Đen M",
      "salePrice": 199000,
      "initialStock": 100,
      "weightGrams": 200
    }
  ]
}
```

---

### 2.5. `ShipmentStatusUpdatedEvent` (Logistics Tracking)
- **Topic**: `shipping.events`
- **Partition Key**: `subOrderId`
- **Mục đích**: Thông báo tiến trình vận chuyển kiện hàng, kích hoạt cập nhật trạng thái đơn hàng bên `order-service` và cơ chế ký quỹ bên `payment-service`.
- **Payload**:
```json
{
  "shipmentId": "ship-5566-7788",
  "subOrderId": "f12c98a1-1234-4567-89ab-cdef01234567",
  "carrierCode": "SPX",
  "waybillNumber": "SPX-VN-88991122",
  "status": "DELIVERED",
  "currentLocation": "Bưu cục Cầu Giấy, Hà Nội",
  "deliveredAt": "2026-11-20T16:00:00Z"
}
```

---

### 2.6. `ReviewSubmittedEvent` (Feedback & Loyalty Reward)
- **Topic**: `review.events`
- **Partition Key**: `productId`
- **Mục đích**: Kích hoạt tự động cộng xu loyalty cho khách hàng (`customer-service`) và tính toán lại điểm đánh giá trung bình cho Sản phẩm (`product-service`) và Gian hàng (`seller-service`).
- **Payload**:
```json
{
  "reviewId": "rev-11223344",
  "orderItemId": "item-7711-2233",
  "productId": "p891b2c3-4d5e-6f7a-8b9c-0d1e2f3a4b5c",
  "skuId": "SKU-IP15P-BLACK-128GB",
  "customerId": "c71a39d8-912f-410a-b28e-5b1239c81190",
  "shopId": "s88a10b2-4433-2211-aa99-1234567890ab",
  "ratingStar": 5,
  "hasMedia": true,
  "rewardPoints": 200,
  "submittedAt": "2026-11-20T16:15:00Z"
}
```
