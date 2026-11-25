# ĐẶC TẢ GIAO DIỆN LẬP TRÌNH ỨNG DỤNG (API SPECIFICATIONS)
**Hệ thống:** CommerceFlow API Gateway & Microservices  
**Chuẩn:** OpenAPI 3.0.3 / RESTful JSON  
**Phiên bản:** 2.0.0 (Comprehensive Multi-vendor Marketplace)  

---

## 1. NGUYÊN TẮC THIẾT KẾ CHUNG (GLOBAL CONVENTIONS)

1. **Base URL Gateway**: `https://api.commerceflow.internal/api/v1`
2. **Authentication**: Header `Authorization: Bearer <JWT_ACCESS_TOKEN>` bắt buộc đối với mọi endpoint nghiệp vụ có đăng nhập.
3. **Idempotency**: Mọi endpoint ghi (`POST`, `PUT`) nhạy cảm về tài chính hoặc giao dịch phải cung cấp Header:
   `Idempotency-Key: <UUIDv4>`
4. **Phân trang chuẩn (Pagination Envelope)**:
   ```json
   {
     "data": [...],
     "pagination": {
       "page": 1,
       "size": 20,
       "totalElements": 1540,
       "totalPages": 77
     }
   }
   ```
5. **Chuẩn mã lỗi HTTP**:
   - `400 Bad Request`: Sai định dạng cú pháp JSON hoặc thiếu trường bắt buộc.
   - `401 Unauthorized`: Token không hợp lệ, thiếu token hoặc token đã hết hạn.
   - `403 Forbidden`: Không có quyền truy cập vào tài nguyên (ví dụ: Seller truy cập đơn hàng của Seller khác).
   - `404 Not Found`: Không tìm thấy tài nguyên (Product, Order, SKU không tồn tại).
   - `409 Conflict`: Vi phạm quy tắc nghiệp vụ/concurrency (Hết tồn kho, voucher đã dùng hết, tranh chấp phiên).
   - `422 Unprocessable Entity`: Dữ liệu đúng cú pháp nhưng vi phạm logic (Giá mua sai lệch, thời gian không hợp lệ).
   - `429 Too Many Requests`: Vượt ngưỡng Rate Limiting (chặn bot, rate limiter theo user/IP).
   - `500 Internal Server Error`: Lỗi hệ thống nội bộ.

---

## 2. IDENTITY & AUTHENTICATION APIS (identity-service)

Toàn bộ các yêu cầu xác thực, cấp phát token và phân quyền được xử lý bởi `identity-service` (Port 8084) và định tuyến qua Gateway tại `/api/v1/auth/**`.

### 2.1. Đăng ký tài khoản (Register)
- **Method**: `POST`
- **Path**: `/auth/register`
- **Auth**: Public
- **Request Body**:
```json
{
  "phoneNumber": "0987654321",
  "email": "customer@example.com",
  "password": "SecurePassword123@",
  "role": "CUSTOMER"
}
```
- **Response 201 Created**:
```json
{
  "code": 200,
  "message": "Success",
  "data": {
    "id": "018d9f10-1234-7111-8000-abcdef123456",
    "phoneNumber": "0987654321",
    "email": "customer@example.com",
    "role": "CUSTOMER",
    "status": "ACTIVE"
  },
  "timestamp": "2026-11-24T15:00:00Z"
}
```

### 2.2. Đăng nhập & Lấy JWT OIDC Tokens (Login)
- **Method**: `POST`
- **Path**: `/auth/login`
- **Auth**: Public
- **Request Body**:
```json
{
  "username": "0987654321",
  "password": "SecurePassword123@"
}
```
- **Response 200 OK**:
```json
{
  "code": 200,
  "message": "Success",
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.ey...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.ey...",
    "token_type": "Bearer",
    "expires_in": 3600,
    "jti": "018d9f12-3456-789a-bcde-0123456789ab",
    "user_id": "018d9f10-1234-7111-8000-abcdef123456",
    "roles": [
      "ROLE_CUSTOMER"
    ]
  },
  "timestamp": "2026-11-24T15:00:00Z"
}
```
> [!NOTE]
> Payload của `access_token` tuân thủ chuẩn OIDC RFC 7519: `sub`, `iss`, `aud`, `exp`, `iat`, `jti`, `preferred_username`, `email`, `roles`, và `realm_access` (Keycloak format).

### 2.3. Làm mới Token (Refresh Token)
- **Method**: `POST`
- **Path**: `/auth/refresh`
- **Auth**: Public
- **Request Body**:
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.ey..."
}
```
- **Response 200 OK**: Trả về cặp `access_token` và `refresh_token` mới tương tự login.

### 2.4. Đăng xuất & Thu hồi phiên (Logout)
- **Method**: `POST`
- **Path**: `/auth/logout`
- **Auth**: Header `Authorization: Bearer <JWT_ACCESS_TOKEN>`
- **Response 200 OK**:
```json
{
  "code": 200,
  "message": "Success",
  "data": "Logged out successfully",
  "timestamp": "2026-11-24T15:00:00Z"
}
```

### 2.5. Tra cứu danh tính phiên hiện tại (Get Current User / Me)
- **Method**: `GET`
- **Path**: `/auth/me`
- **Auth**: Header `Authorization: Bearer <JWT_ACCESS_TOKEN>`
- **Response 200 OK**:
```json
{
  "code": 200,
  "message": "Success",
  "data": {
    "userId": "018d9f10-1234-7111-8000-abcdef123456",
    "username": "0987654321",
    "email": "customer@example.com",
    "roles": [
      "ROLE_CUSTOMER"
    ]
  },
  "timestamp": "2026-11-24T15:00:00Z"
}
```

### 2.6. Khóa công khai JWKS Endpoint (JWKS)
- **Method**: `GET`
- **Path**: `/.well-known/jwks.json` hoặc `/oauth2/jwks`
- **Auth**: Public
- **Response 200 OK**: Trả về danh sách JSON Web Keys (JWKS) cho API Gateway và các Resource Server thẩm định chữ ký token.

---

## 3. PUBLIC & CATALOG APIS (TRƯNG BÀY & TÌM KIẾM SẢN PHẨM)

### 2.1. Lấy Cây Danh mục Ngành hàng (Category Tree)
- **Method**: `GET`
- **Path**: `/categories`
- **Auth**: Public (Không yêu cầu đăng nhập)
- **Response 200 OK**:
```json
[
  {
    "id": "c1a2b3c4-0001-4000-8000-000000000001",
    "name": "Thiết Bị Điện Tử",
    "slug": "thiet-bi-dien-tu",
    "level": 1,
    "iconUrl": "https://cdn.commerceflow.internal/categories/electronics.png",
    "children": [
      {
        "id": "c1a2b3c4-0002-4000-8000-000000000002",
        "name": "Điện Thoại & Phụ Kiện",
        "slug": "dien-thoai-phu-kien",
        "level": 2,
        "children": [
          {
            "id": "c1a2b3c4-0003-4000-8000-000000000003",
            "name": "Điện Thoại Di Động",
            "slug": "dien-thoai-di-dong",
            "level": 3
          }
        ]
      }
    ]
  }
]
```

---

### 2.2. Tìm kiếm & Lọc Sản phẩm Trưng bày (Product Search & Listing)
- **Method**: `GET`
- **Path**: `/products`
- **Auth**: Public
- **Query Params**:
  - `keyword`: Từ khóa tìm kiếm (Full-text search)
  - `categoryId`: UUID danh mục
  - `brandId`: UUID thương hiệu
  - `shopId`: UUID gian hàng
  - `minPrice`, `maxPrice`: Khoảng giá lọc
  - `rating`: Lọc theo số sao tối thiểu (ví dụ: `4` sao trở lên)
  - `sortBy`: `popular` (phổ biến), `sales` (bán chạy), `price_asc`, `price_desc`, `newest`
  - `page`: Trang hiện tại (mặc định `1`)
  - `size`: Số lượng kết quả / trang (mặc định `20`)
- **Response 200 OK**:
```json
{
  "data": [
    {
      "id": "p891b2c3-4d5e-6f7a-8b9c-0d1e2f3a4b5c",
      "name": "Điện thoại Apple iPhone 15 Pro 128GB - Hàng Chính Hãng VN/A",
      "slug": "apple-iphone-15-pro-128gb-vna",
      "thumbnailUrl": "https://cdn.commerceflow.internal/products/iphone15-thumb.jpg",
      "minPrice": 24990000,
      "maxPrice": 27990000,
      "ratingAverage": 4.9,
      "ratingCount": 1280,
      "historicalSold": 4520,
      "shop": {
        "id": "s88a10b2-4433-2211-aa99-1234567890ab",
        "shopName": "Apple Flagship Store",
        "shopType": "MALL"
      }
    }
  ],
  "pagination": { "page": 1, "size": 20, "totalElements": 1, "totalPages": 1 }
}
```

---

### 2.3. Chi tiết Sản phẩm Trưng bày (Product SPU & Biến thể SKUs)
- **Method**: `GET`
- **Path**: `/products/{slugOrId}`
- **Auth**: Public
- **Response 200 OK**:
```json
{
  "id": "p891b2c3-4d5e-6f7a-8b9c-0d1e2f3a4b5c",
  "name": "Điện thoại Apple iPhone 15 Pro - Hàng Chính Hãng VN/A",
  "slug": "apple-iphone-15-pro-vna",
  "descriptionHtml": "<p>Thiết kế titan cao cấp, chip A17 Pro mạnh mẽ...</p>",
  "condition": "NEW",
  "warrantyMonths": 12,
  "shop": {
    "id": "s88a10b2-4433-2211-aa99-1234567890ab",
    "shopName": "Apple Flagship Store",
    "shopSlug": "apple-flagship-store",
    "logoUrl": "https://cdn.commerceflow.internal/shops/apple-logo.png",
    "shopType": "MALL",
    "ratingAverage": 4.95,
    "responseRate": 99
  },
  "images": [
    { "imageUrl": "https://cdn.commerceflow.internal/products/ip15-front.jpg", "isPrimary": true },
    { "imageUrl": "https://cdn.commerceflow.internal/products/ip15-back.jpg", "isPrimary": false }
  ],
  "options": [
    {
      "id": "opt-color",
      "name": "Màu sắc",
      "values": [
        { "id": "val-titan-black", "name": "Titan Đen", "imageUrl": "https://cdn.commerceflow.internal/options/black.jpg" },
        { "id": "val-titan-natural", "name": "Titan Tự Nhiên", "imageUrl": "https://cdn.commerceflow.internal/options/natural.jpg" }
      ]
    },
    {
      "id": "opt-storage",
      "name": "Dung lượng",
      "values": [
        { "id": "val-128gb", "name": "128GB" },
        { "id": "val-256gb", "name": "256GB" }
      ]
    }
  ],
  "skus": [
    {
      "skuId": "SKU-IP15P-BLACK-128GB",
      "skuName": "iPhone 15 Pro Titan Đen 128GB",
      "originalPrice": 28990000,
      "salePrice": 24990000,
      "optionValueIds": ["val-titan-black", "val-128gb"],
      "stockAvailable": 45,
      "weightGrams": 350
    }
  ]
}
```

---

## 3. CUSTOMER APIS (DÀNH CHO NGƯỜI MUA)

### 3.1. Quản lý Sổ Địa chỉ Nhận hàng
- **Method**: `GET` / `POST`
- **Path**: `/customer/addresses`
- **Auth**: `ROLE_CUSTOMER`
- **Request Body (POST)**:
```json
{
  "receiverName": "Nguyễn Văn A",
  "phoneNumber": "0987654321",
  "provinceCity": "Hà Nội",
  "district": "Cầu Giấy",
  "ward": "Dịch Vọng Hậu",
  "streetAddress": "Số 15 ngõ 86 Duy Tân",
  "latitude": 21.031254,
  "longitude": 105.782412,
  "isDefault": true
}
```

---

### 3.2. Khởi tạo Đặt hàng (Checkout)
- **Method**: `POST`
- **Path**: `/orders/checkout`
- **Auth**: `ROLE_CUSTOMER`
- **Headers**: `Idempotency-Key: <UUID>`
- **Request Body**:
```json
{
  "shippingAddressId": "addr-9921",
  "paymentMethod": "MOCK_PAYMENT_GATEWAY",
  "voucherCodes": ["FREESHIP50", "TECHSALE100"],
  "items": [
    {
      "skuId": "SKU-IP15P-BLACK-128GB",
      "sellerId": "s88a10b2-4433-2211-aa99-1234567890ab",
      "quantity": 1,
      "expectedUnitPrice": 24990000
    }
  ]
}
```
- **Response 201 Created**:
```json
{
  "parentOrderId": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "status": "PENDING_PAYMENT",
  "totalAmount": 24990000,
  "discountAmount": 100000,
  "shippingFee": 50000,
  "grandTotal": 24940000,
  "currency": "VND",
  "paymentUrl": "https://gateway.mock.commerceflow.internal/pay/pay-88291a2-3341",
  "expiresAt": "2026-11-20T16:25:00Z",
  "subOrders": [
    {
      "subOrderId": "f12c98a1-1234-4567-89ab-cdef01234567",
      "sellerId": "s88a10b2-4433-2211-aa99-1234567890ab",
      "subtotal": 24990000
    }
  ]
}
```

---

### 3.3. Đánh giá Sản phẩm Sau Khi Hoàn Tất Đơn Hàng (Product Review)
- **Method**: `POST`
- **Path**: `/reviews`
- **Auth**: `ROLE_CUSTOMER`
- **Request Body**:
```json
{
  "orderItemId": "item-7711-2233",
  "ratingStar": 5,
  "comment": "Sản phẩm chính hãng, đóng gói bọc xốp 3 lớp rất kỹ, giao hàng sau 1 ngày!",
  "isAnonymous": false,
  "media": [
    { "type": "IMAGE", "url": "https://cdn.commerceflow.internal/reviews/photo1.jpg" },
    { "type": "VIDEO", "url": "https://cdn.commerceflow.internal/reviews/unboxing.mp4" }
  ]
}
```
- **Response 201 Created**:
```json
{
  "reviewId": "rev-11223344",
  "rewardPointsAwarded": 200,
  "status": "APPROVED"
}
```

---

## 4. SELLER APIS (DÀNH CHO NGƯỜI BÁN & GIAN HÀNG)

### 4.1. Đăng tải Sản phẩm Trưng bày (Create Product SPU & SKUs)
- **Method**: `POST`
- **Path**: `/seller/products`
- **Auth**: `ROLE_SELLER`
- **Request Body**:
```json
{
  "categoryId": "c1a2b3c4-0003-4000-8000-000000000003",
  "brandId": "b11a22c3-4455-6677-8899-001122334455",
  "name": "Áo Thun Nam Thể Thao Pro-Dry",
  "description": "Áo chất liệu co giãn 4 chiều thoáng khí, chống tia UV...",
  "condition": "NEW",
  "images": [
    { "imageUrl": "https://cdn.commerceflow.internal/products/tshirt-thumb.jpg", "isPrimary": true, "displayOrder": 0 }
  ],
  "options": [
    {
      "name": "Màu sắc",
      "values": ["Đen", "Trắng"]
    },
    {
      "name": "Kích cỡ",
      "values": ["M", "L", "XL"]
    }
  ],
  "skus": [
    {
      "skuCode": "SKU-TSHIRT-BLK-M",
      "skuName": "Áo Thun Pro-Dry Đen M",
      "optionValues": ["Đen", "M"],
      "originalPrice": 250000,
      "salePrice": 199000,
      "initialStock": 100,
      "weightGrams": 200
    }
  ]
}
```
- **Response 201 Created**:
```json
{
  "productId": "p9922-3344-5566",
  "status": "ACTIVE",
  "totalSkusCreated": 6
}
```

---

### 4.2. Tiếp nhận và Đóng gói Sub-Order
- **Method**: `POST`
- **Path**: `/seller/orders/{subOrderId}/pack`
- **Auth**: `ROLE_SELLER`
- **Response 200 OK**:
```json
{
  "subOrderId": "f12c98a1-1234-4567-89ab-cdef01234567",
  "status": "READY_TO_SHIP",
  "waybillCode": "SPX-VN-88991122",
  "readyForCarrierPickup": true
}
```

---

### 4.3. Phản hồi Đánh giá của Khách hàng
- **Method**: `POST`
- **Path**: `/seller/reviews/{reviewId}/reply`
- **Auth**: `ROLE_SELLER`
- **Request Body**:
```json
{
  "replyContent": "Cảm ơn quý khách đã tin tưởng mua sắm tại Apple Flagship Store! Chúc bạn có trải nghiệm tuyệt vời."
}
```

---

## 5. SHIPPING & LOGISTICS APIS (VẬN CHUYỂN & HÀNH TRÌNH)

### 5.1. Ước tính Cước phí Vận chuyển (Estimate Shipping Fee)
- **Method**: `POST`
- **Path**: `/shipping/estimate-fee`
- **Auth**: Public hoặc `ROLE_CUSTOMER`
- **Request Body**:
```json
{
  "shopId": "s88a10b2-4433-2211-aa99-1234567890ab",
  "destinationWard": "Dịch Vọng Hậu",
  "destinationDistrict": "Cầu Giấy",
  "destinationProvince": "Hà Nội",
  "totalWeightGrams": 450
}
```
- **Response 200 OK**:
```json
[
  {
    "carrierCode": "SPX",
    "carrierName": "Shopee Xpress",
    "shippingFee": 22000,
    "estimatedDeliveryDays": "1 - 2 ngày"
  },
  {
    "carrierCode": "GHN",
    "carrierName": "Giao Hàng Nhanh",
    "shippingFee": 28000,
    "estimatedDeliveryDays": "24h - Hỏa tốc"
  }
]
```

---

### 5.2. Tra cứu Hành trình Vận đơn (Track Shipment Waybill)
- **Method**: `GET`
- **Path**: `/shipping/track/{waybillNumber}`
- **Auth**: Public
- **Response 200 OK**:
```json
{
  "waybillNumber": "SPX-VN-88991122",
  "carrier": "Shopee Xpress",
  "status": "IN_TRANSIT",
  "events": [
    {
      "time": "2026-11-20T08:30:00Z",
      "location": "Kho phân loại Cầu Giấy",
      "description": "Kiện hàng đã đến kho phân loại Cầu Giấy và đang được chia chọn"
    },
    {
      "time": "2026-11-19T18:00:00Z",
      "location": "Kho Người Bán Hà Đông",
      "description": "Tài xế SPX đã lấy hàng thành công từ Shop"
    }
  ]
}
```

---

## 6. PROMOTION & FLASH SALE APIS

### 6.1. Tra cứu Khung giờ Flash Sale Hiện tại & Sản phẩm Sale
- **Method**: `GET`
- **Path**: `/promotions/flash-sales/current`
- **Auth**: Public
- **Response 200 OK**:
```json
{
  "flashSaleId": "fs-20261120-1600",
  "title": "Flash Sale Khung Giờ Vàng 16:00 - 20:00",
  "startTime": "2026-11-20T16:00:00+07:00",
  "endTime": "2026-11-20T20:00:00+07:00",
  "items": [
    {
      "skuId": "SKU-IP15P-BLACK-128GB",
      "productName": "iPhone 15 Pro 128GB",
      "originalPrice": 28990000,
      "flashSalePrice": 22990000,
      "stockAllocated": 100,
      "stockSold": 78,
      "soldPercentage": 78
    }
  ]
}
```

---

## 7. MOCK PROVIDER APIS (GIẢ LẬP HỆ THỐNG NGOÀI)

### 7.1. Webhook Cổng Thanh toán
- **Method**: `POST`
- **Path**: `/payments/webhook`
- **Auth**: Chữ ký `X-Signature: HMAC_SHA256(payload, secret_key)`
- **Request Body**:
```json
{
  "orderId": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "gatewayTransactionId": "MOCK-BANK-TX-998822",
  "amount": 24940000,
  "currency": "VND",
  "status": "SUCCESS",
  "timestamp": 1732093500
}
```

### 7.2. Webhook Cập nhật Trạng thái 3PL Mock Provider
- **Method**: `POST`
- **Path**: `/shipping/mock-provider/update-status`
- **Auth**: `ROLE_SYSTEM_TESTER`
- **Request Body**:
```json
{
  "waybillCode": "SPX-VN-88991122",
  "status": "DELIVERED",
  "location": "Bưu cục Cầu Giấy, Hà Nội",
  "timestamp": "2026-11-20T16:00:00Z"
}
```
