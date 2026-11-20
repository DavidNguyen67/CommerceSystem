# MÔ HÌNH MÁY TRẠNG THÁI HỆ THỐNG (STATE MACHINES SPECIFICATION)
**Hệ thống:** CommerceFlow Enterprise Multi-vendor Marketplace  
**Kiến trúc:** State Pattern & Distributed State Transition  
**Phiên bản:** 2.0.0 (Comprehensive Shopee-Grade Specification)  

---

## 1. MÁY TRẠNG THÁI ĐƠN HÀNG TỔNG (PARENT ORDER STATE MACHINE)

```mermaid
stateDiagram-v2
    [*] --> PENDING_VALIDATION: Customer Checkout
    PENDING_VALIDATION --> PENDING_PAYMENT: Inventory & Voucher Reserved
    PENDING_VALIDATION --> CANCELLED: Out of Stock / Invalid Voucher

    PENDING_PAYMENT --> CONFIRMED: Payment Captured
    PENDING_PAYMENT --> CANCELLED: Customer Cancelled
    PENDING_PAYMENT --> EXPIRED: Payment TTL Expired (15 mins)

    CONFIRMED --> PROCESSING: Sub-orders Accepted by Sellers
    CONFIRMED --> CANCELLED: Pre-shipping Cancellation (Compensation Triggered)

    PROCESSING --> COMPLETED: All Sub-orders Delivered
    PROCESSING --> PARTIALLY_REFUNDED: One Sub-order Returned/Cancelled

    CANCELLED --> [*]
    EXPIRED --> [*]
    COMPLETED --> [*]
    
    CONFIRMED --> REFUND_PENDING: Late Cancel Request
    REFUND_PENDING --> REFUNDED: Gateway Refund Settled
    REFUNDED --> [*]
```

### Bảng chuyển dịch trạng thái Parent Order (Transition Table)
| Trạng thái nguồn | Sự kiện kích hoạt | Điều kiện bảo vệ (Guards) | Trạng thái đích | Dịch vụ chịu trách nhiệm |
|---|---|---|---|---|
| `PENDING_VALIDATION` | `InventoryReserved` & `VoucherReserved` | Tồn kho và voucher đã giữ chỗ thành công | `PENDING_PAYMENT` | `order-orchestrator` |
| `PENDING_VALIDATION` | `ReservationFailed` | Thiếu hàng hoặc voucher không hợp lệ | `CANCELLED` | `order-orchestrator` |
| `PENDING_PAYMENT` | `PaymentCaptured` | Số tiền khớp 100% với `total_amount` | `CONFIRMED` | `order-orchestrator` |
| `PENDING_PAYMENT` | `PaymentTimeout` | Thời gian vượt quá `expires_at` | `EXPIRED` | `order-orchestrator` |
| `PENDING_PAYMENT` | `CustomerCancelled` | Khách hàng chủ động bấm hủy | `CANCELLED` | `order-service` |
| `CONFIRMED` | `CancelRequested` | Seller chưa chuyển sang trạng thái đóng gói | `REFUND_PENDING` | `order-orchestrator` |
| `REFUND_PENDING` | `PaymentRefunded` | Gateway xác nhận hoàn tiền thành công | `REFUNDED` | `payment-service` |

---

## 2. MÁY TRẠNG THÁI ĐƠN CON CỦA SELLER (SUB-ORDER STATE MACHINE)

```mermaid
stateDiagram-v2
    [*] --> PENDING_CONFIRMATION: Parent Order Confirmed
    PENDING_CONFIRMATION --> PROCESSING: Seller Accepts Order
    PENDING_CONFIRMATION --> CANCELLED: Seller Out of Stock / Cannot Fulfill

    PROCESSING --> PACKED: Seller Printed Waybill & Packed
    PACKED --> SHIPPED: 3PL Courier Scanned & Picked Up
    
    SHIPPED --> DELIVERED: Customer Received Parcel
    SHIPPED --> DELIVERY_FAILED: Courier Cannot Reach Customer
    
    DELIVERY_FAILED --> RETURNED: Returned to Seller Origin Warehouse
    DELIVERED --> RETURN_REQUESTED: Customer Disputed within 3 Days
    
    RETURN_REQUESTED --> RETURNED: Seller QC Approved Return
    RETURN_REQUESTED --> DELIVERED: Dispute Rejected by Admin

    DELIVERED --> COMPLETED: Escrow Settled (> 3 days)
    CANCELLED --> [*]
    RETURNED --> [*]
    COMPLETED --> [*]
```

---

## 3. MÁY TRẠNG THÁI GIAO DỊCH THANH TOÁN (PAYMENT STATE MACHINE)

```mermaid
stateDiagram-v2
    [*] --> INITIATED: Order Created & Payment URL Generated
    INITIATED --> PENDING: User Redirected to Payment Gateway
    
    PENDING --> AUTHORIZED: 2-Phase Auth Hold (If Credit Card)
    PENDING --> CAPTURED: Direct Payment Success (Immediate Webhook)
    PENDING --> FAILED: Card Declined / Insufficient Balance
    PENDING --> TIMEOUT: User Abandoned Payment Session

    AUTHORIZED --> CAPTURED: Saga Confirmed
    AUTHORIZED --> VOIDED: Saga Cancelled (Release Authorization)

    CAPTURED --> REFUND_PENDING: Cancellation / Return Triggered
    REFUND_PENDING --> PARTIALLY_REFUNDED: Partial Sub-order Refund
    REFUND_PENDING --> REFUNDED: Full Order Refunded

    FAILED --> [*]
    TIMEOUT --> [*]
    VOIDED --> [*]
    REFUNDED --> [*]
```

---

## 4. MÁY TRẠNG THÁI KHÓA TỒN KHO (INVENTORY RESERVATION STATE MACHINE)

```mermaid
stateDiagram-v2
    [*] --> PENDING: Reservation Command Enqueued
    PENDING --> RESERVED: Conditional Invariant Update Success
    PENDING --> FAILED: Physical Stock < Requested Quantity

    RESERVED --> COMMITTED: Order Payment Confirmed (Hard Deduct)
    RESERVED --> RELEASED: Order Cancelled by User
    RESERVED --> EXPIRED: TTL Expired Sweeper

    FAILED --> [*]
    COMMITTED --> [*]
    RELEASED --> [*]
    EXPIRED --> [*]
```

---

## 5. MÁY TRẠNG THÁI VẬN CHUYỂN & VẬN ĐƠN (SHIPMENT STATE MACHINE)

```mermaid
stateDiagram-v2
    [*] --> CREATED: Sub-Order Packed & Waybill Generated
    CREATED --> PICKED_UP: 3PL Courier Scanned at Seller Warehouse
    PICKED_UP --> IN_TRANSIT: Arrived at Sorting Hub
    IN_TRANSIT --> OUT_FOR_DELIVERY: Assigned to Shipper for Delivery
    
    OUT_FOR_DELIVERY --> DELIVERED: Customer Successfully Received Parcel
    OUT_FOR_DELIVERY --> DELIVERY_FAILED: Customer Unreachable (Attempt 1-3)
    
    DELIVERY_FAILED --> OUT_FOR_DELIVERY: Re-delivery Scheduled
    DELIVERY_FAILED --> RETURNED: Max Attempts Exceeded, Returned to Seller

    DELIVERED --> [*]
    RETURNED --> [*]
```

---

## 6. MÁY TRẠNG THÁI VÒNG ĐỜI SẢN PHẨM TRƯNG BÀY (PRODUCT SPU LIFECYCLE)

```mermaid
stateDiagram-v2
    [*] --> DRAFT: Seller Creates Product
    DRAFT --> PENDING_APPROVAL: Seller Submits for Review
    PENDING_APPROVAL --> ACTIVE: Admin Approved / Auto-approved
    PENDING_APPROVAL --> REJECTED: Violates Policy / Incomplete Info
    
    REJECTED --> DRAFT: Seller Modifies Info
    ACTIVE --> INACTIVE: Seller Toggles Off / Out of Stock
    INACTIVE --> ACTIVE: Restocked / Seller Turns On
    
    ACTIVE --> BANNED: Admin Bans Due to Infringement/Counterfeit
    BANNED --> [*]
```

---

## 7. CƠ CHẾ BẢO VỆ CHUYỂN DỊCH BẤT HỢP PHÁP (ILLEGAL TRANSITION GUARDS)

Nhằm triệt tiêu lỗi Out-of-Order hoặc Race Condition làm sai lệch dữ liệu:
1. **Nghiêm cấm cập nhật ngược**: Không cho phép chuyển từ `CANCELLED` hoặc `EXPIRED` sang `CONFIRMED`.
2. **Nghiêm cấm Refund đơn chưa trả tiền**: Không thể kích hoạt `RefundPaymentCommand` nếu `payment_status != 'CAPTURED'`.
3. **Database Constraint & Enum Check**: Trạng thái được kiểm soát bằng kiểu dữ liệu `VARCHAR` kết hợp `CHECK (status IN (...))` và kiểm tra `@Version` của JPA Entity:
   ```java
   if (!currentState.canTransitionTo(nextState)) {
       throw new IllegalStateTransitionException(
           String.format("Invalid transition from %s to %s for Order %s", 
               currentState, nextState, orderId)
       );
   }
   ```
