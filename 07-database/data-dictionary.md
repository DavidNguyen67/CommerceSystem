# DATA DICTIONARY & DEVELOPER REFERENCE (TỪ ĐIỂN DỮ LIỆU CHI TIẾT)

**Hệ thống:** CommerceFlow Enterprise Multi-vendor Marketplace  
**Nguồn sự thật (Source of Truth):** Flyway Migrations `V1`–`V11` tại `projects/common-model/src/main/resources/db/migration/`  
**Tổng số bảng:** **65 bảng** (36 bảng nghiệp vụ + 18 bảng Outbox/Inbox + 11 bảng Quartz Scheduler)

---

## 1. BẢN ĐỒ SỞ HỮU BẢNG THEO MICROSERVICE & MIGRATION

| Migration | Context / Domain | Service ghi chính (Owner) | Service đọc / xử lý | Bảng nghiệp vụ | Bảng Outbox / Inbox / Hệ thống |
|---|---|---|---|---|---|
| `V1` | Customer & Identity | `identity-service`, `api-service` | `api-service` | `users`, `customer_profiles`, `customer_addresses` | `customer_outbox`, `customer_inbox` |
| `V2` | Seller & Shop | `api-service` | `api-service`, `event-consumer` | `shops`, `seller_addresses`, `shop_categories` | `seller_outbox`, `seller_inbox` |
| `V3` | Product Catalog | `api-service` | `api-service`, `event-consumer` | `categories`, `brands`, `products`, `product_images`, `product_options`, `product_option_values`, `product_skus`, `sku_option_combinations` | `product_outbox`, `product_inbox` |
| `V4` | Inventory | `event-consumer`, `api-service` | `saga-orchestrator`, `job-service` | `inventories`, `inventory_reservations`, `inventory_audit_logs` | `inventory_outbox`, `inventory_inbox` |
| `V5` | Order | `api-service`, `saga-orchestrator` | `job-service`, `event-consumer` | `parent_orders`, `sub_orders`, `order_items` | `order_outbox`, `order_inbox` |
| `V6` | Saga Orchestrator | `saga-orchestrator` | `saga-orchestrator` | `saga_instances`, `saga_step_executions` | `saga_outbox`, `saga_inbox` |
| `V7` | Payment & Escrow | `api-service` (webhook), `event-consumer` | `saga-orchestrator`, `job-service` | `payment_transactions`, `escrow_ledgers`, `payment_refunds` | `payment_outbox`, `payment_inbox` |
| `V8` | Promotion & Flash Sale | `api-service` | `saga-orchestrator`, `event-consumer` | `campaigns`, `vouchers`, `voucher_conditions`, `voucher_redemptions`, `flash_sales`, `flash_sale_items` | `promotion_outbox` *(chưa có `promotion_inbox`)* |
| `V9` | Shipping & Fulfillment | `event-consumer`, `api-service` | `api-service`, `saga-orchestrator` | `shipping_carriers`, `shipments`, `shipment_tracking_events` | `shipping_outbox`, `shipping_inbox` |
| `V10` | Product Review | `api-service` | `api-service` | `product_reviews`, `review_media`, `review_replies` | `review_outbox` *(chưa có `review_inbox`)* |
| `V11` | Quartz Job Scheduler | `job-service` | `job-service` | *(Không có bảng nghiệp vụ)* | 11 bảng `QRTZ_*` |

### Quy ước chung trên toàn bộ Entity (`common-model`)
- **Audit columns:** Phần lớn bảng nghiệp vụ kế thừa `BaseEntity` (`created_at DATE NOT NULL DEFAULT CURRENT_DATE`, `updated_at DATE NOT NULL DEFAULT CURRENT_DATE`, múi giờ `Asia/Ho_Chi_Minh`). Các bảng log/event/outbox/inbox dùng `TIMESTAMPTZ NOT NULL DEFAULT NOW()`.
- **Primary Key:** Đa số dùng `UUID` sinh bằng `@GeneratedUuidV7` (`UuidV7Generator`) ở tầng Java hoặc `gen_random_uuid()` mặc định ở DB. Ngoại lệ: `product_skus.id` và `inventories.sku_id` dùng `VARCHAR(64)`, `*_inbox.message_id` dùng `VARCHAR(64)`.

---

## 1.5. MA TRẬN LUỒNG NGHIỆP VỤ -> BẢNG SỬ DỤNG

| Luồng nghiệp vụ | Bảng đọc (Read) | Bảng ghi / cập nhật (Write) | Service thực thi |
|---|---|---|---|
| **Đăng ký / Đăng nhập / Profile** | `users`, `customer_profiles` | `users`, `customer_profiles`, `customer_addresses`, `customer_outbox` | `identity-service`, `api-service` |
| **Xác thực SĐT & Email (OTP)** | `users`, Redis (OTP và cooldown) | `users` (`is_verified_*`), `customer_outbox`, Redis | `identity-service`, `event-consumer` |
| **Mở Shop & Quản lý kho bán** | `users`, `shops` | `shops`, `seller_addresses`, `shop_categories`, `seller_outbox` | `api-service` |
| **Đăng bán sản phẩm (SPU -> SKU)** | `categories`, `brands`, `shops` | `products`, `product_images`, `product_options`, `product_option_values`, `product_skus`, `sku_option_combinations`, `inventories`, `product_outbox` | `api-service`, `event-consumer` |
| **Checkout & Tách đơn Multi-Vendor** | `customer_addresses`, `product_skus`, `vouchers`, `voucher_conditions`, `flash_sale_items` | `parent_orders`, `sub_orders`, `order_items`, `order_outbox`, `saga_instances`, `saga_step_executions` | `api-service`, `saga-orchestrator` |
| **Giữ kho & Hoàn kho (Anti-Overselling)** | `inventories`, `inventory_reservations` | `inventories`, `inventory_reservations`, `inventory_audit_logs`, `inventory_outbox`, `inventory_inbox` | `event-consumer`, `job-service` |
| **Áp Voucher & Flash Sale** | `campaigns`, `vouchers`, `voucher_conditions`, `flash_sales`, `flash_sale_items` | `vouchers`, `voucher_redemptions`, `flash_sale_items`, `promotion_outbox` | `api-service`, `event-consumer` |
| **Thanh toán, Escrow & Hoàn tiền** | `parent_orders`, `sub_orders`, `payment_transactions` | `payment_transactions`, `escrow_ledgers`, `payment_refunds`, `payment_outbox`, `payment_inbox` | `api-service` (webhook), `event-consumer`, `job-service` |
| **Vận chuyển & Tracking** | `shipping_carriers`, `seller_addresses`, `sub_orders` | `shipments`, `shipment_tracking_events`, `sub_orders`, `shipping_outbox` | `event-consumer`, `api-service` |
| **Đánh giá sản phẩm** | `order_items`, `product_reviews` | `product_reviews`, `review_media`, `review_replies`, `review_outbox` | `api-service` |
| **Housekeeping & Hết hạn tự động** | `parent_orders`, `inventory_reservations`, `escrow_ledgers` | `QRTZ_*`, `parent_orders`, `inventory_reservations`, `escrow_ledgers` | `job-service` |

---

## 2. V1 — CUSTOMER & IDENTITY (`V1__init_customer_identity_schema.sql`)

### Chức năng nghiệp vụ các bảng V1
- **`users`**: Trung tâm xác thực & phân quyền (AuthN/AuthZ). Lưu thông tin đăng nhập (`phone_number`/`email`), mật khẩu băm (`password_hash`), vai trò (`CUSTOMER`/`SELLER`/`ADMIN`), trạng thái xác thực (`is_verified_phone_number`, `is_verified_email`) và trạng thái khóa tài khoản (`ACTIVE`/`LOCKED`/`SUSPENDED`). `identity-service` đọc và ghi bảng này khi đăng nhập, đăng ký hoặc xác thực OTP. Các service khác xác thực qua JWT claims. Theo thiết kế, Redis lưu OTP và cooldown. `customer_outbox` lưu `PHONE_VERIFICATION_REQUESTED` hoặc `EMAIL_VERIFICATION_REQUESTED` để `event-consumer` gửi SMS hoặc email. Với email, [event chỉ chứa tham chiếu đến challenge](../05-kafka/event-contracts.md#27-email_verification_requested).
- **`customer_profiles`**: Lưu thông tin hồ sơ hiển thị và chương trình khách hàng thân thiết (Loyalty). Tự động khởi tạo 1-1 theo `users.id` khi khách hàng đăng ký, dùng để tích điểm (`reward_points`) và nâng hạng (`BRONZE` -> `PLATINUM`) sau khi đơn hàng hoàn tất.
- **`customer_addresses`**: Sổ địa chỉ nhận hàng của khách (nhiều địa chỉ/khách, có cờ `is_default` và tọa độ `latitude`/`longitude` để tính phí ship). Khi checkout, hệ thống **snapshot** địa chỉ được chọn vào `parent_orders.shipping_address_snapshot` để nếu khách sửa/xóa địa chỉ sau này thì đơn cũ không bị thay đổi.

### 2.1. `users` — Entity: `User`
- **PK:** `id` (`UUID`) | **Unique:** `phone_number`, `email`
- **Enums:** `UserRole` (`CUSTOMER`, `SELLER`, `ADMIN`), `UserStatus` (`ACTIVE`, `LOCKED`, `SUSPENDED`)

| Cột | Kiểu SQL | Ràng buộc / Mặc định | Mô tả |
|---|---|---|---|
| `id` | `UUID` | `PK, DEFAULT gen_random_uuid()` | Định danh duy nhất tài khoản (UUIDv7) |
| `phone_number` | `VARCHAR(20)` | `NOT NULL, UNIQUE` | Số điện thoại đăng nhập (đã chuẩn hóa) |
| `email` | `VARCHAR(128)` | `UNIQUE` | Email người dùng (tùy chọn) |
| `password_hash` | `VARCHAR(255)` | `NOT NULL` | Mật khẩu băm (BCrypt) |
| `role` | `VARCHAR(32)` | `NOT NULL, DEFAULT 'CUSTOMER'` | Vai trò chính (`CUSTOMER`, `SELLER`, `ADMIN`) |
| `status` | `VARCHAR(32)` | `NOT NULL, DEFAULT 'ACTIVE'` | Trạng thái tài khoản (`ACTIVE`, `LOCKED`, `SUSPENDED`) |
| `is_verified_phone_number` | `BOOLEAN` | `NOT NULL, DEFAULT FALSE` | Đã xác thực số điện thoại qua OTP SMS hay chưa *(đã có trong `User.java`, cần bổ sung vào Flyway migration)* |
| `is_verified_email` | `BOOLEAN` | `NOT NULL, DEFAULT FALSE` | Trạng thái xác thực email. Cột được bổ sung trong Flyway V12. |
| `created_at` | `DATE` | `NOT NULL, DEFAULT CURRENT_DATE` | Ngày tạo |
| `updated_at` | `DATE` | `NOT NULL, DEFAULT CURRENT_DATE` | Ngày cập nhật |

### 2.2. `customer_profiles` — Entity: `CustomerProfile`
- **PK/FK:** `customer_id` (`UUID` -> `users(id) ON DELETE CASCADE`)
- **Enums:** `Gender` (`MALE`, `FEMALE`, `OTHER`), `LoyaltyTier` (`BRONZE`, `SILVER`, `GOLD`, `PLATINUM`)

| Cột | Kiểu SQL | Ràng buộc / Mặc định | Mô tả |
|---|---|---|---|
| `customer_id` | `UUID` | `PK, FK -> users.id` | Khóa chính dùng chung với `users.id` (1-1) |
| `full_name` | `VARCHAR(128)` | `NOT NULL` | Họ tên hiển thị |
| `avatar_url` | `VARCHAR(512)` | `NULL` | URL ảnh đại diện |
| `gender` | `VARCHAR(16)` | `NULL` | Giới tính (`MALE`, `FEMALE`, `OTHER`) |
| `date_of_birth` | `DATE` | `NULL` | Ngày sinh |
| `loyalty_tier` | `VARCHAR(32)` | `NOT NULL, DEFAULT 'BRONZE'` | Hạng thành viên (`BRONZE`, `SILVER`, `GOLD`, `PLATINUM`) |
| `reward_points` | `INT` | `NOT NULL, DEFAULT 0, CHECK (>= 0)` | Điểm thưởng tích lũy |
| `created_at`, `updated_at` | `DATE` | `NOT NULL, DEFAULT CURRENT_DATE` | Ngày tạo / cập nhật |

### 2.3. `customer_addresses` — Entity: `CustomerAddress`
- **PK:** `id` (`UUID`) | **FK:** `customer_id` -> `users(id) ON DELETE CASCADE` | **Index:** `idx_customer_addresses_cid(customer_id)`

| Cột | Kiểu SQL | Ràng buộc / Mặc định | Mô tả |
|---|---|---|---|
| `id` | `UUID` | `PK` | Định danh địa chỉ |
| `customer_id` | `UUID` | `NOT NULL, FK -> users.id` | Chủ sở hữu địa chỉ |
| `receiver_name` | `VARCHAR(128)` | `NOT NULL` | Tên người nhận hàng |
| `phone_number` | `VARCHAR(20)` | `NOT NULL` | SĐT người nhận |
| `province_city` | `VARCHAR(100)` | `NOT NULL` | Tỉnh / Thành phố |
| `district` | `VARCHAR(100)` | `NOT NULL` | Quận / Huyện |
| `ward` | `VARCHAR(100)` | `NOT NULL` | Phường / Xã |
| `street_address` | `VARCHAR(255)` | `NOT NULL` | Địa chỉ chi tiết (số nhà, đường) |
| `postal_code` | `VARCHAR(16)` | `NULL` | Mã bưu chính |
| `latitude`, `longitude` | `NUMERIC(10, 7)` | `NULL` | Tọa độ GPS phục vụ tính khoảng cách |
| `is_default` | `BOOLEAN` | `NOT NULL, DEFAULT FALSE` | Đánh dấu địa chỉ mặc định |
| `created_at`, `updated_at` | `DATE` | `NOT NULL, DEFAULT CURRENT_DATE` | Ngày tạo / cập nhật |

---

## 3. V2 — SELLER & SHOP (`V2__init_seller_shop_schema.sql`)

### Chức năng nghiệp vụ các bảng V2
- **`shops`**: Đại diện cho một Gian hàng / Nhà bán trên sàn (1 `user_id` sở hữu 1 shop). Lưu thông tin nhận diện (`shop_name`, `shop_slug`, logo/banner), phân loại uy tín (`STANDARD`, `PREFERRED`, `MALL`), trạng thái hoạt động (`ACTIVE`, `SUSPENDED`, `CLOSED`) và các chỉ số vận hành (`rating_average`, `rating_count`, `response_rate`) được cập nhật bất đồng bộ từ sự kiện review/chat.
- **`seller_addresses`**: Quản lý các điểm kho của Shop theo mục đích (`PICKUP`: kho lấy hàng, `RETURN`: kho nhận hàng hoàn trả, `WAREHOUSE`: kho lưu trữ). Khi tạo vận đơn (`shipments`), hệ thống lấy địa chỉ `PICKUP` mặc định để **snapshot** vào `pickup_address_snapshot`.
- **`shop_categories`**: Bộ sưu tập / danh mục nội bộ do Seller tự tạo để sắp xếp sản phẩm trên trang chủ riêng của Shop (khác với `categories` là cây ngành hàng chuẩn của toàn sàn).

### 3.1. `shops` — Entity: `Shop`
- **PK:** `id` (`UUID`) | **Unique:** `user_id`, `shop_name`, `shop_slug`
- **Enums:** `ShopType` (`STANDARD`, `MALL`, `PREFERRED`), `ShopStatus` (`ACTIVE`, `SUSPENDED`, `CLOSED`)

| Cột | Kiểu SQL | Ràng buộc / Mặc định | Mô tả |
|---|---|---|---|
| `id` | `UUID` | `PK` | Định danh gian hàng |
| `user_id` | `UUID` | `NOT NULL, UNIQUE` | Logical FK tới `users.id` (chủ shop) |
| `shop_name` | `VARCHAR(128)` | `NOT NULL, UNIQUE` | Tên gian hàng |
| `shop_slug` | `VARCHAR(150)` | `NOT NULL, UNIQUE` | Slug URL thân thiện |
| `logo_url`, `banner_url` | `VARCHAR(512)` | `NULL` | Ảnh logo và banner shop |
| `description` | `TEXT` | `NULL` | Mô tả giới thiệu gian hàng |
| `shop_type` | `VARCHAR(32)` | `NOT NULL, DEFAULT 'STANDARD'` | Loại shop (`STANDARD`, `MALL`, `PREFERRED`) |
| `status` | `VARCHAR(32)` | `NOT NULL, DEFAULT 'ACTIVE'` | Trạng thái hoạt động |
| `rating_average` | `NUMERIC(3, 2)` | `NOT NULL, DEFAULT 5.00` | Điểm đánh giá trung bình |
| `rating_count` | `INT` | `NOT NULL, DEFAULT 0` | Tổng số lượt đánh giá |
| `response_rate` | `INT` | `NOT NULL, DEFAULT 100` | Tỉ lệ phản hồi chat (%) |
| `created_at`, `updated_at` | `DATE` | `NOT NULL, DEFAULT CURRENT_DATE` | Ngày tạo / cập nhật |

### 3.2. `seller_addresses` — Entity: `SellerAddress`
- **PK:** `id` (`UUID`) | **FK:** `shop_id` -> `shops(id) ON DELETE CASCADE` | **Index:** `idx_seller_addresses_shop(shop_id)`
- **Enum:** `SellerAddressType` (`PICKUP`, `RETURN`, `WAREHOUSE`)

| Cột | Kiểu SQL | Ràng buộc / Mặc định | Mô tả |
|---|---|---|---|
| `id` | `UUID` | `PK` | Định danh kho/địa chỉ |
| `shop_id` | `UUID` | `NOT NULL, FK -> shops.id` | Gian hàng sở hữu |
| `address_type` | `VARCHAR(32)` | `NOT NULL` | Loại địa chỉ (`PICKUP`, `RETURN`, `WAREHOUSE`) |
| `contact_name`, `phone_number` | `VARCHAR(128)`, `VARCHAR(20)` | `NOT NULL` | Người liên hệ & SĐT kho |
| `province_city`, `district`, `ward`, `street_address` | `VARCHAR(...)` | `NOT NULL` | Địa chỉ hành chính |
| `latitude`, `longitude` | `NUMERIC(10, 7)` | `NULL` | Tọa độ kho |
| `is_default` | `BOOLEAN` | `NOT NULL, DEFAULT FALSE` | Kho mặc định |
| `created_at`, `updated_at` | `DATE` | `NOT NULL, DEFAULT CURRENT_DATE` | Ngày tạo / cập nhật |

### 3.3. `shop_categories` — Entity: `ShopCategory`
- **PK:** `id` (`UUID`) | **FK:** `shop_id` -> `shops(id) ON DELETE CASCADE` | **Index:** `idx_shop_categories_shop(shop_id)`

| Cột | Kiểu SQL | Ràng buộc / Mặc định | Mô tả |
|---|---|---|---|
| `id` | `UUID` | `PK` | Định danh danh mục riêng của shop |
| `shop_id` | `UUID` | `NOT NULL, FK -> shops.id` | Gian hàng sở hữu |
| `name` | `VARCHAR(128)` | `NOT NULL` | Tên danh mục hiển thị trong shop |
| `display_order` | `INT` | `NOT NULL, DEFAULT 0` | Thứ tự sắp xếp |
| `is_active` | `BOOLEAN` | `NOT NULL, DEFAULT TRUE` | Trạng thái hiển thị |
| `created_at`, `updated_at` | `DATE` | `NOT NULL, DEFAULT CURRENT_DATE` | Ngày tạo / cập nhật |

---

## 4. V3 — PRODUCT CATALOG (`V3__init_product_catalog_schema.sql`)

### Chức năng nghiệp vụ các bảng V3 (Mô hình SPU – SKU)
- **`categories`**: Cây ngành hàng chuẩn của toàn sàn (hỗ trợ đa cấp qua `parent_id`, `level`). Dùng để phân loại sản phẩm, dựng menu điều hướng, lọc tìm kiếm và áp dụng điều kiện voucher theo ngành hàng.
- **`brands`**: Danh mục thương hiệu sản phẩm (Apple, Samsung, Nike...), có cờ `is_mall_brand` để gắn nhãn chính hãng và lọc tìm kiếm theo thương hiệu.
- **`products` (SPU — Standard Product Unit)**: Thông tin gốc của sản phẩm dùng chung cho mọi biến thể (tên, mô tả, ngành hàng, thương hiệu, tình trạng `NEW`/`USED`/`REFURBISHED`, bảo hành, trạng thái duyệt/bán). Một SPU không bán trực tiếp mà phải có ít nhất một `product_skus`.
- **`product_images`**: Thư viện ảnh/media trưng bày của sản phẩm gốc, có `is_primary` để chọn ảnh đại diện trên thẻ sản phẩm và `display_order` để sắp xếp slide.
- **`product_options` & `product_option_values`**: Định nghĩa các trục phân loại biến thể của SPU (ví dụ `product_options.name = "Màu sắc"` -> `product_option_values`: `"Đỏ"`, `"Xanh"`; `"Kích cỡ"` -> `"M"`, `"L"`). Mỗi giá trị có thể gắn `image_url` riêng (ví dụ chọn màu Đỏ sẽ đổi ảnh sang áo Đỏ).
- **`product_skus` (SKU — Stock Keeping Unit)**: Đơn vị hàng hóa thực tế có thể cho vào giỏ và đặt mua. Lưu giá niêm yết (`original_price`), giá bán (`sale_price`), mã vạch (`barcode`) và kích thước/khối lượng đóng gói (`weight_grams`, `length_cm`, `width_cm`, `height_cm`) để tính phí vận chuyển.
- **`sku_option_combinations`**: Bảng nối N-N ánh xạ mỗi SKU với tổ hợp giá trị phân loại cụ thể (ví dụ `SKU-001` = `Màu Đỏ` + `Size L`), đảm bảo tính duy nhất của biến thể.

### 4.1. `categories` — Entity: `Category`
- **PK:** `id` (`UUID`) | **FK:** `parent_id` -> `categories(id) ON DELETE RESTRICT` | **Unique:** `slug` | **Index:** `idx_categories_parent(parent_id)`

| Cột | Kiểu SQL | Ràng buộc / Mặc định | Mô tả |
|---|---|---|---|
| `id` | `UUID` | `PK` | Định danh ngành hàng |
| `parent_id` | `UUID` | `NULL, FK -> categories.id` | Danh mục cha (cây phân cấp đa tầng) |
| `name` | `VARCHAR(128)` | `NOT NULL` | Tên ngành hàng |
| `slug` | `VARCHAR(150)` | `NOT NULL, UNIQUE` | Slug URL |
| `level` | `INT` | `NOT NULL, DEFAULT 1` | Cấp độ trong cây (1 = Root) |
| `icon_url` | `VARCHAR(512)` | `NULL` | Icon danh mục |
| `display_order` | `INT` | `NOT NULL, DEFAULT 0` | Thứ tự hiển thị |
| `is_active` | `BOOLEAN` | `NOT NULL, DEFAULT TRUE` | Trạng thái kích hoạt |
| `created_at`, `updated_at` | `DATE` | `NOT NULL, DEFAULT CURRENT_DATE` | Ngày tạo / cập nhật |

### 4.2. `brands` — Entity: `Brand`
- **PK:** `id` (`UUID`) | **Unique:** `name`, `slug` | **Enum:** `BrandStatus`

| Cột | Kiểu SQL | Ràng buộc / Mặc định | Mô tả |
|---|---|---|---|
| `id` | `UUID` | `PK` | Định danh thương hiệu |
| `name` | `VARCHAR(128)` | `NOT NULL, UNIQUE` | Tên thương hiệu |
| `slug` | `VARCHAR(150)` | `NOT NULL, UNIQUE` | Slug URL |
| `logo_url` | `VARCHAR(512)` | `NULL` | Logo thương hiệu |
| `is_mall_brand` | `BOOLEAN` | `NOT NULL, DEFAULT FALSE` | Thương hiệu chính hãng Mall |
| `status` | `VARCHAR(32)` | `NOT NULL, DEFAULT 'ACTIVE'` | Trạng thái |
| `created_at`, `updated_at` | `DATE` | `NOT NULL, DEFAULT CURRENT_DATE` | Ngày tạo / cập nhật |

### 4.3. `products` (SPU) — Entity: `Product`
- **PK:** `id` (`UUID`) | **FK:** `category_id` -> `categories(id)`, `brand_id` -> `brands(id)`
- **Indexes:** `idx_products_shop(shop_id)`, `idx_products_category(category_id)`, `idx_products_status(status)`
- **Enums:** `ProductCondition` (`NEW`, `USED`, `REFURBISHED`), `ProductStatus` (`ACTIVE`, `DRAFT`, `INACTIVE`, `BANNED`)

| Cột | Kiểu SQL | Ràng buộc / Mặc định | Mô tả |
|---|---|---|---|
| `id` | `UUID` | `PK` | Định danh sản phẩm gốc (SPU) |
| `shop_id` | `UUID` | `NOT NULL` | Logical FK tới `shops.id` |
| `category_id` | `UUID` | `NOT NULL, FK -> categories.id` | Ngành hàng của sản phẩm |
| `brand_id` | `UUID` | `NULL, FK -> brands.id` | Thương hiệu |
| `name` | `VARCHAR(255)` | `NOT NULL` | Tên sản phẩm |
| `slug` | `VARCHAR(300)` | `NOT NULL` | Slug URL |
| `short_description` | `VARCHAR(500)` | `NULL` | Mô tả ngắn |
| `description` | `TEXT` | `NOT NULL` | Mô tả chi tiết (HTML/Markdown) |
| `condition` | `VARCHAR(32)` | `NOT NULL, DEFAULT 'NEW'` | Tình trạng hàng |
| `warranty_months` | `INT` | `DEFAULT 0` | Số tháng bảo hành |
| `status` | `VARCHAR(32)` | `NOT NULL, DEFAULT 'ACTIVE'` | Trạng thái bán |
| `created_at`, `updated_at` | `DATE` | `NOT NULL, DEFAULT CURRENT_DATE` | Ngày tạo / cập nhật |

### 4.4. `product_images`, `product_options`, `product_option_values`, `product_skus`, `sku_option_combinations`
- `product_images` (`ProductImage`): `id (UUID PK)`, `product_id (FK -> products ON DELETE CASCADE)`, `image_url (VARCHAR(512))`, `is_primary (BOOLEAN)`, `display_order (INT)`, `created_at`, `updated_at`. Index: `idx_product_images_prod(product_id)`.
- `product_options` (`ProductOption`): `id (UUID PK)`, `product_id (FK -> products ON DELETE CASCADE)`, `name (VARCHAR(64))` *(vd: Màu sắc, Kích cỡ)*, `display_order (INT)`.
- `product_option_values` (`ProductOptionValue`): `id (UUID PK)`, `option_id (FK -> product_options ON DELETE CASCADE)`, `value_name (VARCHAR(64))` *(vd: Đỏ, XL)*, `image_url (VARCHAR(512))`.
- `product_skus` (`ProductSku`):
  - **PK:** `id` (`VARCHAR(64)` — mã SKU, không phải UUID) | **FK:** `product_id` -> `products(id) ON DELETE CASCADE`
  - **Indexes:** `idx_skus_product(product_id)`, `idx_skus_shop(shop_id)` | **Enum:** `SkuStatus`
  - Cột: `shop_id (UUID NOT NULL)`, `sku_name (VARCHAR(255))`, `original_price (NUMERIC(15,2))`, `sale_price (NUMERIC(15,2))`, `barcode (VARCHAR(64))`, `weight_grams (INT > 0, DEFAULT 200)`, `length_cm (INT DEFAULT 10)`, `width_cm (INT DEFAULT 10)`, `height_cm (INT DEFAULT 10)`, `status (VARCHAR(32) DEFAULT 'ACTIVE')`, `created_at`, `updated_at`.
- `sku_option_combinations` (`SkuOptionCombination`): `id (UUID PK)`, `sku_id (VARCHAR(64) FK -> product_skus ON DELETE CASCADE)`, `option_value_id (UUID FK -> product_option_values ON DELETE CASCADE)`, `UNIQUE(sku_id, option_value_id)`.

---

## 5. V4 — INVENTORY (`V4__init_inventory_schema.sql`)

### Chức năng nghiệp vụ các bảng V4 (Chống Overselling & Kiểm toán)
- **`inventories`**: Lưu tồn kho theo từng `sku_id`. Tách bạch `physical_quantity` (hàng thực tế trong kho) và `reserved_quantity` (hàng đang bị giữ cho đơn chưa thanh toán/chưa xuất). Tồn khả dụng (Available Stock) = `physical_quantity - reserved_quantity`. Dùng `@Version` + Conditional Atomic Update (`WHERE physical_quantity - reserved_quantity >= :qty`) để ngăn bán vượt tồn kho khi flash sale có hàng nghìn request đồng thời.
- **`inventory_reservations`**: Ghi nhận từng phiếu giữ kho gắn với `order_id` và thời hạn `expires_at`. Khi khách đặt đơn -> tạo bản ghi `RESERVED` và tăng `reserved_quantity`; khi thanh toán thành công -> chuyển `COMMITTED` và trừ cả `physical_quantity` lẫn `reserved_quantity`; khi hủy đơn hoặc quá hạn (`job-service` quét `status = 'RESERVED' AND expires_at < NOW()`) -> chuyển `RELEASED`/`EXPIRED` và trả lại `reserved_quantity`.
- **`inventory_audit_logs`**: Sổ cái bất biến (append-only) ghi lại mọi biến động tồn kho (nhập kho, giữ kho, xuất kho, hoàn kho, điều chỉnh kiểm kê) kèm số dư `balance_physical`, `balance_reserved` và `reference_id` (mã đơn/phiếu nhập) để đối soát.

### 5.1. `inventories` — Entity: `Inventory`
- **PK:** `sku_id` (`VARCHAR(64)`) | **Index:** `idx_inventories_seller(seller_id)`
- **Constraints:** `physical_quantity >= 0`, `reserved_quantity >= 0`, `chk_stock_integrity (physical_quantity >= reserved_quantity)`
- **Concurrency:** Optimistic Locking với cột `version` (`@Version`) + Conditional Atomic Update chống overselling.

| Cột | Kiểu SQL | Ràng buộc / Mặc định | Mô tả |
|---|---|---|---|
| `sku_id` | `VARCHAR(64)` | `PK` | Mã SKU (1-1 với `product_skus.id`) |
| `seller_id` | `UUID` | `NOT NULL` | Chủ shop sở hữu tồn kho |
| `physical_quantity` | `INT` | `NOT NULL, DEFAULT 0, CHECK (>= 0)` | Tổng tồn kho vật lý thực tế |
| `reserved_quantity` | `INT` | `NOT NULL, DEFAULT 0, CHECK (>= 0)` | Số lượng đang bị khóa giữ cho đơn chờ thanh toán |
| `version` | `BIGINT` | `NOT NULL, DEFAULT 0` | Phiên bản Optimistic Locking |
| `created_at`, `updated_at` | `DATE` | `NOT NULL, DEFAULT CURRENT_DATE` | Ngày tạo / cập nhật |

### 5.2. `inventory_reservations` — Entity: `InventoryReservation`
- **PK:** `id` (`UUID`) | **FK:** `sku_id` -> `inventories(sku_id)` | **Enums:** `InventoryReservationStatus` (`RESERVED`, `COMMITTED`, `RELEASED`, `EXPIRED`)
- **Indexes:** `idx_inv_res_order_id(order_id)`, `idx_inv_res_status_expires(status, expires_at)`

| Cột | Kiểu SQL | Ràng buộc / Mặc định | Mô tả |
|---|---|---|---|
| `id` | `UUID` | `PK` | Định danh phiên giữ kho |
| `order_id` | `UUID` | `NOT NULL` | Logical FK tới `parent_orders.id` |
| `sku_id` | `VARCHAR(64)` | `NOT NULL, FK -> inventories.sku_id` | SKU được giữ |
| `quantity` | `INT` | `NOT NULL, CHECK (> 0)` | Số lượng giữ |
| `status` | `VARCHAR(32)` | `NOT NULL` | Trạng thái giữ kho |
| `expires_at` | `TIMESTAMPTZ` | `NOT NULL` | Thời điểm hết hạn giữ kho (để `job-service` giải phóng) |
| `created_at`, `updated_at` | `DATE` | `NOT NULL, DEFAULT CURRENT_DATE` | Ngày tạo / cập nhật |

### 5.3. `inventory_audit_logs` — Entity: `InventoryAuditLog`
- **PK:** `id` (`UUID`) | **Index:** `idx_inv_audit_sku(sku_id)` | **Enum:** `InventoryChangeType`
- Cột: `sku_id (VARCHAR(64))`, `seller_id (UUID)`, `change_type (VARCHAR(32))`, `quantity_delta (INT)`, `balance_physical (INT)`, `balance_reserved (INT)`, `reference_id (VARCHAR(64))`, `created_at (TIMESTAMPTZ NOT NULL DEFAULT NOW())`.

---

## 6. V5 — ORDER (`V5__init_order_schema.sql`)

### Chức năng nghiệp vụ các bảng V5 (Mô hình Đơn Tổng – Đơn Con Multi-Vendor)
- **`parent_orders`**: Đơn hàng tổng đại diện cho 1 lần khách hàng bấm Checkout (có thể mua hàng của nhiều Shop cùng lúc). Lưu tổng tiền thanh toán (`grand_total`), phương thức thanh toán, `shipping_address_snapshot` (JSONB bất biến), và `idempotency_key` (`UNIQUE(customer_id, idempotency_key)`) để chống tạo trùng đơn khi client retry mạng.
- **`sub_orders`**: Khi checkout giỏ hàng đa người bán, `parent_orders` được tách thành nhiều `sub_orders` theo từng `seller_id`. Mỗi `sub_orders` có vòng đời vận hành độc lập (Shop xác nhận, đóng gói, gắn `waybill_code` vận đơn, giao hàng, tính `seller_payout` sau khi trừ chiết khấu/phí).
- **`order_items`**: Chi tiết từng SKU trong một `sub_order`. Lưu **snapshot** tên sản phẩm, tên SKU, ảnh, đơn giá (`unit_price`) và thành tiền tại thời điểm đặt hàng để lịch sử đơn hàng luôn chính xác dù Shop có đổi giá hoặc xóa sản phẩm sau đó.

### 6.1. `parent_orders` — Entity: `ParentOrder`
- **PK:** `id` (`UUID`) | **Unique:** `uq_customer_idempotency (customer_id, idempotency_key)`
- **Indexes:** `idx_parent_orders_customer(customer_id)`, `idx_parent_orders_status(status)`
- **Enums:** `ParentOrderStatus`, `PaymentMethod`

| Cột | Kiểu SQL | Ràng buộc / Mặc định | Mô tả |
|---|---|---|---|
| `id` | `UUID` | `PK` | Mã đơn hàng tổng |
| `customer_id` | `UUID` | `NOT NULL` | Khách hàng đặt đơn |
| `status` | `VARCHAR(32)` | `NOT NULL` | Trạng thái đơn tổng |
| `total_amount` | `NUMERIC(15, 2)` | `NOT NULL` | Tổng tiền hàng trước giảm giá |
| `discount_amount` | `NUMERIC(15, 2)` | `NOT NULL, DEFAULT 0.00` | Tổng tiền giảm giá |
| `shipping_fee` | `NUMERIC(15, 2)` | `NOT NULL, DEFAULT 0.00` | Tổng phí vận chuyển |
| `grand_total` | `NUMERIC(15, 2)` | `NOT NULL` | Số tiền khách thực trả |
| `payment_method` | `VARCHAR(32)` | `NOT NULL` | Phương thức thanh toán |
| `idempotency_key` | `VARCHAR(64)` | `NOT NULL` | Khóa chống tạo trùng đơn khi retry |
| `shipping_address_snapshot` | `JSONB` | `NOT NULL` | Snapshot địa chỉ giao hàng tại thời điểm đặt |
| `version` | `BIGINT` | `NOT NULL, DEFAULT 0` | Optimistic Locking |
| `created_at`, `updated_at` | `DATE` | `NOT NULL, DEFAULT CURRENT_DATE` | Ngày tạo / cập nhật |

### 6.2. `sub_orders` — Entity: `SubOrder`
- **PK:** `id` (`UUID`) | **FK:** `parent_order_id` -> `parent_orders(id) ON DELETE CASCADE`
- **Indexes:** `idx_sub_orders_parent(parent_order_id)`, `idx_sub_orders_seller(seller_id)`, `idx_sub_orders_status(status)` | **Enum:** `SubOrderStatus`
- Cột: `parent_order_id (UUID)`, `seller_id (UUID)`, `status (VARCHAR(32))`, `subtotal (NUMERIC(15,2))`, `shipping_fee (NUMERIC(15,2) DEFAULT 0.00)`, `discount_amount (NUMERIC(15,2) DEFAULT 0.00)`, `seller_payout (NUMERIC(15,2) DEFAULT 0.00)`, `waybill_code (VARCHAR(64))`, `created_at`, `updated_at`.

### 6.3. `order_items` — Entity: `OrderItem`
- **PK:** `id` (`UUID`) | **FK:** `sub_order_id` -> `sub_orders(id) ON DELETE CASCADE` | **Index:** `idx_order_items_sub_order(sub_order_id)`
- Cột: `sub_order_id (UUID)`, `sku_id (VARCHAR(64))`, `product_id (UUID)`, `product_name (VARCHAR(255))`, `sku_name (VARCHAR(255))`, `product_image_url (VARCHAR(512))`, `quantity (INT CHECK > 0)`, `unit_price (NUMERIC(15,2))`, `total_price (NUMERIC(15,2))`, `created_at`, `updated_at`.

---

## 7. V6 — SAGA ORCHESTRATOR (`V6__init_saga_orchestrator_schema.sql`)

### Chức năng nghiệp vụ các bảng V6 (Điều phối giao dịch phân tán)
- **`saga_instances`**: Lưu trạng thái máy trạng thái (State Machine) của một giao dịch phân tán gắn với `order_id` và `correlation_id` duy nhất (ví dụ luồng `CREATE_ORDER_SAGA`: `RESERVE_INVENTORY` -> `APPLY_PROMOTION` -> `CREATE_PAYMENT` -> `CONFIRM_ORDER`). Khi một bước thất bại, Orchestrator dựa vào `current_step` và `payload` để kích hoạt các bước bù trừ (Compensating Transactions) theo thứ tự ngược lại.
- **`saga_step_executions`**: Nhật ký chi tiết từng bước gọi sang microservice đích (`target_service`), lưu `request_payload`, `response_payload`, số lần `retry_count`, lỗi `error_detail` và thời gian bắt đầu/kết thúc. Phục vụ debug, theo dõi SLA và tự động retry/recover khi sự cố.

### 7.1. `saga_instances` — Entity: `SagaInstance`
- **PK:** `id` (`UUID`) | **Unique:** `correlation_id` | **Indexes:** `idx_saga_status(status)`, `idx_saga_order(order_id)`
- **Enums:** `SagaType`, `SagaStatus`
- Cột: `saga_type (VARCHAR(64))`, `correlation_id (VARCHAR(64) UNIQUE)`, `order_id (UUID)`, `status (VARCHAR(32))`, `current_step (VARCHAR(64))`, `payload (JSONB)`, `error_message (TEXT)`, `created_at (DATE)`, `updated_at (DATE)`.

### 7.2. `saga_step_executions` — Entity: `SagaStepExecution`
- **PK:** `id` (`UUID`) | **FK:** `saga_instance_id` -> `saga_instances(id) ON DELETE CASCADE` | **Index:** `idx_saga_steps_instance(saga_instance_id)`
- **Enum:** `SagaStepStatus`
- Cột: `saga_instance_id (UUID)`, `step_name (VARCHAR(64))`, `target_service (VARCHAR(64))`, `status (VARCHAR(32))`, `request_payload (JSONB)`, `response_payload (JSONB)`, `retry_count (INT DEFAULT 0)`, `error_detail (TEXT)`, `started_at (TIMESTAMPTZ DEFAULT NOW())`, `completed_at (TIMESTAMPTZ)`.

---

## 8. V7 — PAYMENT & ESCROW (`V7__init_payment_schema.sql`)

### Chức năng nghiệp vụ các bảng V7 (Thanh toán, Ký quỹ & Hoàn tiền)
- **`payment_transactions`**: Ghi nhận giao dịch thanh toán của khách hàng cho `parent_orders` (`order_id` unique) qua cổng thanh toán (VNPay, MoMo, Stripe, COD). Lưu `gateway_transaction_id` để chống xử lý trùng webhook, trạng thái thanh toán (`PENDING`, `SUCCESS`, `FAILED`) và `raw_response` JSONB để đối soát tài chính.
- **`escrow_ledgers`**: Tài khoản ký quỹ (Escrow) bảo vệ người mua theo từng `sub_order_id`. Tiền thanh toán của khách không chuyển thẳng cho Seller ngay mà được giữ ở trạng thái `HOLDING` cho đến qua thời gian bảo vệ/đổi trả (`release_due_at`). Khi đến hạn và không có khiếu nại, `job-service` hoặc `event-consumer` giải ngân (`RELEASED`/`SETTLED`) số tiền `net_payout_amount` (đã trừ `platform_fee`) cho Seller.
- **`payment_refunds`**: Lưu yêu cầu và kết quả hoàn tiền (`order_id`, hoặc hoàn từng phần theo `sub_order_id`) khi đơn bị hủy sau thanh toán, giao thất bại hoặc trả hàng thành công, gắn với `refund_gateway_id` để đối soát cổng thanh toán.

- **`payment_transactions`** (`PaymentTransaction`): `id (UUID PK)`, `order_id (UUID UNIQUE)`, `gateway_transaction_id (VARCHAR(128) UNIQUE)`, `amount (NUMERIC(15,2))`, `currency (VARCHAR(8) DEFAULT 'VND')`, `status (VARCHAR(32) — PaymentTransactionStatus)`, `payment_method (VARCHAR(32) — PaymentMethod)`, `raw_response (JSONB)`, `created_at`, `updated_at`.
- **`escrow_ledgers`** (`EscrowLedger`): `id (UUID PK)`, `sub_order_id (UUID UNIQUE)`, `seller_id (UUID)`, `net_payout_amount (NUMERIC(15,2))`, `platform_fee (NUMERIC(15,2))`, `status (VARCHAR(32) — EscrowStatus)`, `release_due_at (TIMESTAMPTZ)`, `settled_at (TIMESTAMPTZ)`, `created_at`, `updated_at`. Indexes: `idx_escrow_seller(seller_id)`, `idx_escrow_status_due(status, release_due_at)`.
- **`payment_refunds`** (`PaymentRefund`): `id (UUID PK)`, `order_id (UUID)`, `sub_order_id (UUID NULL)`, `refund_gateway_id (VARCHAR(128) UNIQUE)`, `amount (NUMERIC(15,2))`, `reason (VARCHAR(255))`, `status (VARCHAR(32) — PaymentRefundStatus)`, `created_at`, `updated_at`.

---

## 9. V8 — PROMOTION & FLASH SALE (`V8__init_promotion_schema.sql`)

### Chức năng nghiệp vụ các bảng V8
- **`campaigns`**: Chiến dịch khuyến mãi lớn theo mùa/sự kiện (ví dụ: *11.11 Siêu Sale*, *Tết 2026*), gom nhóm nhiều `vouchers` và `flash_sales` dưới cùng một banner và khung thời gian.
- **`vouchers`**: Định nghĩa mã giảm giá của Sàn (`seller_id IS NULL`) hoặc của Shop (`seller_id IS NOT NULL`). Hỗ trợ giảm theo phần trăm (`PERCENTAGE` kèm trần `max_discount_amount`) hoặc số tiền cố định (`FIXED_AMOUNT`), kiểm soát đơn tối thiểu (`min_spend`), tổng lượt dùng toàn sàn (`total_usage_limit` với constraint `current_usage_count <= total_usage_limit`) và giới hạn mỗi user (`per_user_limit`).
- **`voucher_conditions`**: Danh sách điều kiện ràng buộc động (lưu dạng `condition_type` + `condition_value` JSONB), ví dụ: chỉ áp dụng cho danh mục Điện tử, chỉ áp dụng cho phương thức thanh toán ví điện tử, hoặc chỉ cho khách hàng mới/hạng GOLD.
- **`voucher_redemptions`**: Nhật ký mỗi lần khách hàng sử dụng voucher cho đơn hàng (`customer_id`, `voucher_id`, `order_id`, `discount_amount`, `status`). Dùng để đếm số lần đã dùng của từng user (`per_user_limit`) và hoàn lượt voucher nếu đơn bị hủy.
- **`flash_sales`**: Khung giờ Flash Sale (ví dụ *00:00 - 02:00*, *12:00 - 14:00*) với trạng thái `SCHEDULED` -> `ACTIVE` -> `ENDED`.
- **`flash_sale_items`**: Danh sách SKU tham gia từng khung giờ Flash Sale với giá ưu đãi `flash_sale_price`, quỹ hàng phân bổ riêng `stock_allocated`, số lượng đã bán `stock_sold` (`stock_sold <= stock_allocated`) và giới hạn mua mỗi người (`user_purchase_limit`) để chống đầu cơ/bot.

- **`campaigns`** (`Campaign`): `id (UUID PK)`, `title (VARCHAR(255))`, `slug (VARCHAR(255) UNIQUE)`, `banner_url (VARCHAR(512))`, `start_time (TIMESTAMPTZ)`, `end_time (TIMESTAMPTZ)`, `status (VARCHAR(32) DEFAULT 'UPCOMING' — CampaignStatus)`, `created_at`, `updated_at`.
- **`vouchers`** (`Voucher`): `id (UUID PK)`, `campaign_id (UUID FK -> campaigns)`, `seller_id (UUID NULL)`, `code (VARCHAR(64) UNIQUE)`, `name (VARCHAR(255))`, `discount_type (VARCHAR(32) — DiscountType)`, `discount_value (NUMERIC(15,2))`, `max_discount_amount (NUMERIC(15,2))`, `min_spend (NUMERIC(15,2) DEFAULT 0.00)`, `total_usage_limit (INT DEFAULT 1000)`, `current_usage_count (INT DEFAULT 0)`, `per_user_limit (INT DEFAULT 1)`, `valid_from (TIMESTAMPTZ)`, `expires_at (TIMESTAMPTZ)`, `is_active (BOOLEAN DEFAULT TRUE)`, `created_at`, `updated_at`. Check: `chk_voucher_usage (current_usage_count <= total_usage_limit)`. Indexes: `idx_vouchers_code`, `idx_vouchers_seller`.
- **`voucher_conditions`** (`VoucherCondition`): `id (UUID PK)`, `voucher_id (UUID FK -> vouchers ON DELETE CASCADE)`, `condition_type (VARCHAR(64) — VoucherConditionType)`, `condition_value (JSONB)`.
- **`voucher_redemptions`** (`VoucherRedemption`): `id (UUID PK)`, `voucher_id (UUID FK -> vouchers)`, `customer_id (UUID)`, `order_id (UUID)`, `discount_amount (NUMERIC(15,2))`, `status (VARCHAR(32) — VoucherRedemptionStatus)`, `redeemed_at (TIMESTAMPTZ DEFAULT NOW())`. Index: `idx_voucher_redemp_cust(customer_id, voucher_id)`.
- **`flash_sales`** (`FlashSale`): `id (UUID PK)`, `campaign_id (UUID FK -> campaigns)`, `title (VARCHAR(128))`, `start_time (TIMESTAMPTZ)`, `end_time (TIMESTAMPTZ)`, `status (VARCHAR(32) DEFAULT 'SCHEDULED' — FlashSaleStatus)`, `created_at`, `updated_at`.
- **`flash_sale_items`** (`FlashSaleItem`): `id (UUID PK)`, `flash_sale_id (UUID FK -> flash_sales ON DELETE CASCADE)`, `sku_id (VARCHAR(64))`, `flash_sale_price (NUMERIC(15,2))`, `stock_allocated (INT CHECK > 0)`, `stock_sold (INT DEFAULT 0)`, `user_purchase_limit (INT DEFAULT 1)`, `created_at`, `updated_at`. Constraints: `uq_flash_sale_sku (flash_sale_id, sku_id)`, `chk_flash_stock (stock_sold <= stock_allocated)`.

---

## 10. V9 — SHIPPING & FULFILLMENT (`V9__init_shipping_schema.sql`)

### Chức năng nghiệp vụ các bảng V9
- **`shipping_carriers`**: Danh mục đối tác vận chuyển tích hợp (GHN, GHTK, Viettel Post, J&T...), lưu mã hãng (`carrier_code`), hotline và `api_endpoint` để gọi API tạo vận đơn / tra cứu hành trình.
- **`shipments`**: Vận đơn giao hàng gắn 1-1 với từng `sub_order_id` (`waybill_number` là mã vận đơn duy nhất). Lưu **snapshot** địa chỉ lấy hàng (`pickup_address_snapshot`) và địa chỉ giao hàng (`delivery_address_snapshot`), khối lượng gói hàng, tiền thu hộ (`cod_amount`), phí ship và thời gian dự kiến/thực tế giao hàng.
- **`shipment_tracking_events`**: Lịch sử từng chặng di chuyển của kiện hàng (nhận hàng tại bưu cục -> trung chuyển kho -> đang giao -> giao thành công/hoàn hàng), nhận từ webhook của đơn vị vận chuyển để hiển thị timeline cho người mua và kích hoạt cập nhật trạng thái `sub_orders`.

- **`shipping_carriers`** (`ShippingCarrier`): `id (UUID PK)`, `carrier_code (VARCHAR(32) UNIQUE — CarrierCode)`, `carrier_name (VARCHAR(128))`, `contact_hotline (VARCHAR(20))`, `api_endpoint (VARCHAR(255))`, `is_active (BOOLEAN DEFAULT TRUE)`, `created_at`, `updated_at`.
- **`shipments`** (`Shipment`): `id (UUID PK)`, `sub_order_id (UUID UNIQUE)`, `carrier_id (UUID FK -> shipping_carriers)`, `waybill_number (VARCHAR(64) UNIQUE)`, `status (VARCHAR(32) — ShipmentStatus)`, `pickup_address_snapshot (JSONB)`, `delivery_address_snapshot (JSONB)`, `package_weight_grams (INT)`, `cod_amount (NUMERIC(15,2) DEFAULT 0.00)`, `shipping_fee (NUMERIC(15,2))`, `estimated_delivery_at (TIMESTAMPTZ)`, `actual_delivery_at (TIMESTAMPTZ)`, `created_at`, `updated_at`. Indexes: `idx_shipments_carrier`, `idx_shipments_waybill`.
- **`shipment_tracking_events`** (`ShipmentTrackingEvent`): `id (UUID PK)`, `shipment_id (UUID FK -> shipments ON DELETE CASCADE)`, `event_status (VARCHAR(64) — TrackingEventStatus)`, `hub_location (VARCHAR(255))`, `event_description (TEXT)`, `occurred_at (TIMESTAMPTZ)`, `created_at (TIMESTAMPTZ DEFAULT NOW())`. Index: `idx_tracking_shipment(shipment_id)`.

---

## 11. V10 — PRODUCT REVIEW (`V10__init_review_schema.sql`)

### Chức năng nghiệp vụ các bảng V10
- **`product_reviews`**: Đánh giá của người mua sau khi nhận hàng thành công. Ràng buộc `order_item_id UNIQUE` đảm bảo **chỉ người đã mua mặt hàng đó mới được đánh giá 1 lần** (Verified Purchase). Hỗ trợ chấm 1–5 sao, nhận xét, ẩn danh (`is_anonymous`) và ẩn vi phạm (`is_hidden`). Sau khi tạo, phát event qua `review_outbox` để cập nhật lại điểm trung bình của `shops` và sản phẩm.
- **`review_media`**: Ảnh và video thực tế khách hàng đính kèm vào đánh giá (tối ưu hiển thị theo `display_order`).
- **`review_replies`**: Phản hồi chính thức của Shop cho từng đánh giá (`review_id UNIQUE` — mỗi đánh giá chỉ có 1 phản hồi từ Shop).

- **`product_reviews`** (`ProductReview`): `id (UUID PK)`, `order_item_id (UUID UNIQUE)`, `product_id (UUID)`, `sku_id (VARCHAR(64))`, `customer_id (UUID)`, `shop_id (UUID)`, `rating_star (INT CHECK 1..5)`, `comment (TEXT)`, `is_anonymous (BOOLEAN DEFAULT FALSE)`, `is_hidden (BOOLEAN DEFAULT FALSE)`, `created_at`, `updated_at`. Indexes: `idx_reviews_product`, `idx_reviews_shop`.
- **`review_media`** (`ReviewMedia`): `id (UUID PK)`, `review_id (UUID FK -> product_reviews ON DELETE CASCADE)`, `media_type (VARCHAR(16) — ReviewMediaType)`, `media_url (VARCHAR(512))`, `display_order (INT DEFAULT 0)`, `created_at`, `updated_at`.
- **`review_replies`** (`ReviewReply`): `id (UUID PK)`, `review_id (UUID UNIQUE FK -> product_reviews ON DELETE CASCADE)`, `shop_id (UUID)`, `reply_content (TEXT)`, `created_at`, `updated_at`.

---

## 12. BẢNG OUTBOX & INBOX (18 BẢNG — V1 ĐẾN V10)

### Chức năng nghiệp vụ Outbox & Inbox
- **`*_outbox` (Transactional Outbox Pattern)**: Khi một service thay đổi dữ liệu nghiệp vụ (ví dụ tạo `parent_orders`, trừ `inventories`, tạo `product_reviews`), service ghi thêm 1 bản ghi sự kiện vào bảng `*_outbox` **trong cùng một Database Transaction**. Debezium CDC (hoặc worker) đọc bảng này để đẩy sự kiện lên Kafka, đảm bảo không bao giờ xảy ra tình trạng "lưu DB thành công nhưng mất message Kafka".
- **`*_inbox` (Idempotent Consumer Pattern)**: Trước khi consumer xử lý một message từ Kafka, nó kiểm tra và insert `message_id` vào `*_inbox` (PK). Nếu `message_id` đã tồn tại, consumer bỏ qua để đảm bảo mỗi sự kiện chỉ được xử lý đúng một lần (Exactly-once processing), tránh trừ kho hoặc cộng tiền 2 lần khi Kafka retry.

Tất cả bảng `*_outbox` và `*_inbox` có cấu trúc đồng nhất:
- **`*_outbox`** (`id UUID PK`, `aggregate_type VARCHAR(64)`, `aggregate_id VARCHAR(64)`, `event_type VARCHAR(128)`, `payload JSONB`, `created_at TIMESTAMPTZ DEFAULT NOW()`): `customer_outbox`, `seller_outbox`, `product_outbox`, `inventory_outbox`, `order_outbox`, `saga_outbox`, `payment_outbox`, `promotion_outbox`, `shipping_outbox`, `review_outbox` (10 bảng).
- **`*_inbox`** (`message_id VARCHAR(64) PK`, `consumer_group VARCHAR(128)`, `processed_at TIMESTAMPTZ DEFAULT NOW()`): `customer_inbox`, `seller_inbox`, `product_inbox`, `inventory_inbox`, `order_inbox`, `saga_inbox`, `payment_inbox`, `shipping_inbox` (8 bảng).

---

## 13. V11 — QUARTZ SCHEDULER (`V11__init_quartz_schema.sql` — 11 BẢNG)

### Chức năng nghiệp vụ Quartz Scheduler (`job-service`)
- Cho phép `job-service` chạy nhiều node song song (Clustered Mode) mà **không bị chạy trùng lặp job** nhờ cơ chế khóa phân tán trên PostgreSQL (`QRTZ_LOCKS`, `QRTZ_SCHEDULER_STATE`).
- Phục vụ các tác vụ nền định kỳ của sàn: hủy đơn quá hạn thanh toán (`OrderExpirationJob`), giải phóng `inventory_reservations` hết hạn `expires_at`, giải ngân `escrow_ledgers` đến hạn `release_due_at`, và dọn dẹp dữ liệu `*_outbox` / `*_inbox` cũ.

Dùng cho `job-service` với `PostgreSQLDelegate` (Clustered JDBC JobStore):
- `QRTZ_JOB_DETAILS`: Định nghĩa job (`SCHED_NAME`, `JOB_NAME`, `JOB_GROUP` PK).
- `QRTZ_TRIGGERS`: Thông tin trigger (`SCHED_NAME`, `TRIGGER_NAME`, `TRIGGER_GROUP` PK; FK tới `QRTZ_JOB_DETAILS`).
- `QRTZ_SIMPLE_TRIGGERS`, `QRTZ_CRON_TRIGGERS`, `QRTZ_SIMPROP_TRIGGERS`, `QRTZ_BLOB_TRIGGERS`: Cấu hình chi tiết theo loại trigger (FK tới `QRTZ_TRIGGERS`).
- `QRTZ_CALENDARS`, `QRTZ_PAUSED_TRIGGER_GRPS`: Lịch loại trừ và nhóm trigger tạm dừng.
- `QRTZ_FIRED_TRIGGERS`: Nhật ký trigger đang chạy trên từng instance.
- `QRTZ_SCHEDULER_STATE`: Trạng thái heartbeat các node `job-service`.
- `QRTZ_LOCKS`: Khóa đồng bộ cluster (`TRIGGER_ACCESS`, `STATE_ACCESS`).
