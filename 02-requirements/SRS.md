# ĐẶC TẢ YÊU CẦU PHẦN MỀM (SOFTWARE REQUIREMENTS SPECIFICATION - SRS)
**Hệ thống:** CommerceFlow — Enterprise Distributed E-commerce Marketplace  
**Tiêu chuẩn:** IEEE 830 / ISO/IEC/IEEE 29148  
**Phiên bản:** 2.0.0 (Comprehensive Shopee-Grade Specification)  

---

## 1. GIỚI THIỆU (INTRODUCTION)

### 1.1. Mục đích (Purpose)
Tài liệu này đặc tả chi tiết toàn bộ các yêu cầu phần mềm cho hệ thống **CommerceFlow**, đóng vai trò là hợp đồng kỹ thuật giữa đội ngũ kiến trúc, kỹ sư backend, frontend, QA và DevOps.

### 1.2. Phạm vi sản phẩm (Product Scope)
CommerceFlow là một nền tảng sàn thương mại điện tử đa người bán phân tán chịu tải cao, hỗ trợ mô hình Multi-seller, Multi-warehouse, Multi-customer. Hệ thống bao gồm:
- Cổng API Gateway định tuyến và xác thực tập trung.
- Lưới 12 microservices độc lập nghiệp vụ theo Bounded Contexts.
- Quản lý trưng bày sản phẩm theo cấu trúc SPU/SKU, cây danh mục ngành hàng đa cấp và gian hàng người bán.
- Hệ thống điều phối giao dịch phân tán (Saga Orchestration & Choreography).
- Hệ thống truyền thông sự kiện bất đồng bộ Apache Kafka có bảo đảm At-Least-Once và Exactly-Once processing tại tầng nghiệp vụ.
- Hạ tầng lưu trữ phân tán gồm PostgreSQL 16 (quan hệ), Redis 7.2 (In-memory cache & locking) và Debezium CDC Outbox Pattern.

---

## 2. KIẾN TRÚC MÔ HÌNH HÓA DỮ LIỆU & RÀNG BUỘC PHÂN TÁN (DISTRIBUTED CONSTRAINTS)

```mermaid
graph TD
    Client[Client Web/Mobile] -->|HTTPS / JWT| APIGW[API Gateway Spring Cloud Gateway]
    
    subgraph Synchronous HTTP Edge
        APIGW --> AuthSvc[Identity Service]
        APIGW --> CustSvc[Customer Service]
        APIGW --> SellerSvc[Seller Service]
        APIGW --> ProductSvc[Product Catalog Service]
        APIGW --> CartSvc[Cart Service]
        APIGW --> OrderSvc[Order Service]
        APIGW --> ShipSvc[Shipping Service]
        APIGW --> ReviewSvc[Review Service]
    end

    subgraph Asynchronous Event Backbone
        OrderSvc -->|Transactional Outbox| KafkaBroker[(Apache Kafka Cluster)]
        OrchSvc[Order Orchestrator] <-->|Commands & Events| KafkaBroker
        InvSvc[Inventory Service] <-->|Reserve & Commit| KafkaBroker
        PaySvc[Payment Service] <-->|Capture & Refund| KafkaBroker
        PromoSvc[Promotion Service] <-->|Validate & Redeem| KafkaBroker
        ShipSvc <-->|Waybills & Tracking| KafkaBroker
        ReviewSvc -->|Submit Reviews| KafkaBroker
        ProductSvc <-->|Sync Catalog & Rating| KafkaBroker
        NotiSvc[Notification Service] <--|Consume Events| KafkaBroker
    end
```

---

## 3. TIÊU CHÍ NGHIỆP VỤ & MA TRẬN TRACEABILITY (BUSINESS TRACEABILITY MATRIX)

| BRD ID | SRS Module | Microservice chịu trách nhiệm | Kafka Topic liên quan | Tiêu chí nghiệm thu (Acceptance Criteria) |
|---|---|---|---|---|
| **BR-ORD-001** | Multi-Seller Checkout | `order-service`, `order-orchestrator` | `order.checkout.initiated` | 1 Parent Order sinh ra đúng $N$ Sub-Orders tương ứng $N$ Sellers; không có seller nào bị gộp nhầm. |
| **BR-INV-001** | Zero Overselling | `inventory-service` | `inventory.commands` | Khi 1.000 requests cùng tranh chấp 10 items, đúng 10 reservations thành công, 990 requests còn lại trả về lỗi Out-of-Stock mà không gây âm kho. |
| **BR-PAY-001** | Payment Reconciliation | `payment-service` | `payment.events` | Idempotent Webhook ngăn chặn thanh toán lặp 100%; số tiền match tuyệt đối với Parent Order. |
| **BR-PRO-001** | Dual-tier Voucher Stacking | `promotion-service` | `promotion.commands` | Khách hàng áp dụng đồng thời Voucher Sàn và Voucher Shop hợp lệ; chặn gian lận lặp voucher trong cùng 1 mili-giây. |
| **BR-ORD-005** | Auto Expiration | `order-orchestrator` | `order.events` | Đơn hàng không thanh toán sau 15 phút (hoặc 3 phút Flash Sale) được tự động nhả tồn kho và chuyển trạng thái `EXPIRED`. |
| **BR-CAT-001** | SPU/SKU Display & Media | `product-service` | `product.events` | SPU hiển thị đầy đủ hình ảnh, video, phân loại màu/size; khi chọn biến thể lập tức cập nhật giá bán và tồn kho tương ứng. |
| **BR-SHOP-001** | Seller Pickup Warehouse | `seller-service` | - | Người bán bắt buộc phải có ít nhất 1 kho lấy hàng (`PICKUP`) hợp lệ mới được kích hoạt giao hàng cho Sub-Order. |
| **BR-SHIP-001** | Dynamic Shipping & Tracking | `shipping-service` | `shipping.events` | Tự động tính cước động theo khoảng cách/khối lượng; tích hợp sinh mã vận đơn và cập nhật dòng thời gian lộ trình giao hàng. |
| **BR-REV-001** | Post-Delivery Review & Coins | `review-service`, `customer-service` | `review.events` | Khách hàng chỉ được đánh giá sau khi đơn chuyển `DELIVERED`; đánh giá kèm ảnh/video được tự động cộng Shopee Xu thưởng. |
