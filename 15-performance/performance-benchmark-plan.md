# KẾ HOẠCH ĐO KIỂM HIỆU NĂNG & BENCHMARK (PERFORMANCE BENCHMARK PLAN)
**Hệ thống:** CommerceFlow Load Testing Suite  
**Công cụ:** k6 / Grafana k6 Cloud  
**Phiên bản:** 1.0.0  

---

## 1. MỤC TIÊU & CÁC KỊCH BẢN TẢI (BENCHMARK SCENARIOS)

| Kịch bản | Virtual Users (VUs) | Tốc độ gửi (Throughput) | Mục đích kiểm định | Tiêu chí vượt qua (Pass Criteria) |
|---|---|---|---|---|
| **Kịch bản 1: Baseline Load** | 100 VUs | ~500 req/s | Kiểm tra độ ổn định thông thường | P95 < 100ms, Error rate = 0% |
| **Kịch bản 2: High Traffic** | 500 VUs | ~2,500 req/s | Giờ cao điểm mua sắm (Mega Sale Day) | P95 < 250ms, Error rate < 0.1% |
| **Kịch bản 3: Peak Stress Test** | 1,000 VUs | ~5,000 req/s | Đánh giá độ co giãn và bão hòa tài nguyên | P99 < 500ms, DB Connection Pool < 80% |
| **Kịch bản 4: Flash Sale Spikes** | 2,000 VUs | Bùng nổ tức thì trong 5s | Tranh chấp 1 SKU duy nhất có 50 items | **Zero Overselling!** Số vi phạm tồn kho = 0 |

---

## 2. K6 LOAD TESTING SCRIPT MẪU (FLASH SALE SCENARIO)

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

export const options = {
  scenarios: {
    flash_sale_spike: {
      executor: 'per-vu-iterations',
      vus: 1000,
      iterations: 1,
      maxDuration: '10s',
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<300', 'p(99)<600'],
    http_req_failed: ['rate<0.01'], // Lỗi mạng hệ thống phải < 1%
  },
};

const BASE_URL = 'http://localhost:8080/api/v1';

export default function () {
  const idempotencyKey = uuidv4();
  const customerId = `cust-${__VU}`;

  const payload = JSON.stringify({
    shippingAddressId: 'addr-default',
    paymentMethod: 'MOCK_PAYMENT_GATEWAY',
    voucherCodes: [],
    items: [
      {
        skuId: 'SKU-FLASH-SALE-IPHONE',
        sellerId: 's88a10b2-4433-2211-aa99-1234567890ab',
        quantity: 1,
        expectedUnitPrice: 1000,
      },
    ],
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer mock-jwt-token-for-${customerId}`,
      'Idempotency-Key': idempotencyKey,
    },
  };

  const res = http.post(`${BASE_URL}/orders/checkout`, payload, params);

  // Chấp nhận 201 Created (mua thành công) hoặc 409 Conflict (hết hàng do Flash Sale)
  check(res, {
    'Status is 201 or 409': (r) => r.status === 201 || r.status === 409,
    'No 500 Internal Error': (r) => r.status !== 500,
  });
}
```

---

## 3. THIẾT LẬP TỐI ƯU THÔNG SỐ HẠ TẦNG (PERFORMANCE TUNING PARAMETERS)

### 3.1. HikariCP Connection Pool (Spring Boot)
```properties
spring.datasource.hikari.maximum-pool-size=30
spring.datasource.hikari.minimum-idle=10
spring.datasource.hikari.idle-timeout=30000
spring.datasource.hikari.connection-timeout=5000
spring.datasource.hikari.max-lifetime=1800000
```

### 3.2. Java 21 Virtual Threads (Project Loom)
Kích hoạt Virtual Threads trong `application.properties` để xử lý I/O blocking mà không tốn Platform Threads:
```properties
spring.threads.virtual.enabled=true
```

### 3.3. Kafka Producer Tối ưu hóa Thông lượng
```properties
spring.kafka.producer.properties.linger.ms=20
spring.kafka.producer.properties.batch.size=65536
spring.kafka.producer.properties.compression.type=zstd
spring.kafka.producer.properties.max.in.flight.requests.per.connection=5
```
