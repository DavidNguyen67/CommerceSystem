# ADR-007: KIẾN TRÚC XÁC THỰC OIDC CLAIMS, TÁCH LỚP AUTH PROVIDER VÀ PHÂN QUYỀN STATELESS
**Trạng thái:** ACCEPTED  
**Ngày quyết định:** 2026-11-24  
**Người quyết định:** Architecture & Security Team  

---

## 1. BỐI CẢNH (CONTEXT)
Trong quá trình bổ sung `identity-service` vào bundle microservices của CommerceFlow, hệ thống đối mặt với 3 thách thức bảo mật và kiến trúc:
1. **Ràng buộc phụ thuộc cơ sở dữ liệu (Database Coupling)**: Nếu các dịch vụ downstream (`api-service`, `gateway-service`) phải truy vấn bảng `users` trong cơ sở dữ liệu trên mỗi HTTP request để kiểm tra role/status, hệ thống sẽ gặp hiện tượng nghẽn I/O database nghiêm trọng khi tải cao (hàng chục nghìn req/sec).
2. **Khóa chặt nhà cung cấp định danh (Vendor Lock-in)**: Nếu hard-code trực tiếp logic đăng nhập, xác thực mật khẩu và sinh token vào thẳng business service, khi doanh nghiệp muốn chuyển dịch sang các giải pháp Identity Provider (IdP) tiêu chuẩn doanh nghiệp như **Keycloak**, **Okta**, hoặc **Auth0**, đội ngũ phát triển sẽ phải viết lại hoặc sửa đổi sâu luồng nghiệp vụ trên toàn bộ các microservices.
3. **Thiếu chuẩn hóa Claims trong Token**: Nếu token JWT phát hành sử dụng các trường tùy biến không theo chuẩn quốc tế, các công cụ kiểm toán, API Gateway hoặc các bên thứ ba tích hợp sẽ khó phân tích cú pháp và xác thực đồng bộ.

---

## 2. QUYẾT ĐỊNH (DECISION)
Chúng tôi quyết định thiết kế tầng xác thực và định danh dựa trên **3 nguyên tắc kiến trúc cốt lõi**:

### Nguyên tắc 1: JWT chuẩn OIDC Claims (RFC 7519 / OpenID Connect)
Mọi JWT token phát hành từ `identity-service` hoặc IdP bên ngoài bắt buộc phải tuân thủ chuẩn OIDC Claims được định nghĩa tại `com.commerce.common_model.security.OidcStandardClaims`:
- `sub`: User UUID định danh (`users.id`).
- `iss`: Issuer định danh nguồn cấp phát (ví dụ: `https://auth.commerceflow.com`).
- `aud`: Audience (ví dụ: `commerce-api`).
- `exp`: UNIX epoch expiration timestamp.
- `iat`: UNIX epoch issued at timestamp.
- `jti`: JWT Unique ID (UUIDv7 string) phục vụ thu hồi và kiểm tra Redis Blacklist.
- `preferred_username`: Số điện thoại hoặc username người dùng.
- `email`: Địa chỉ email.
- `roles`: Mảng danh sách quyền ứng dụng (`["ROLE_CUSTOMER", "ROLE_SELLER", "ROLE_ADMIN"]`).
- `realm_access`: Map chứa `roles` (`{"roles": [...]}`) tương thích cấu trúc mặc định của Keycloak.
- `token_type`: Phân biệt `access` và `refresh`.

### Nguyên tắc 2: Tách lớp Auth Provider, Token Provider và Role Claims Adapter Interface
Tách biệt hoàn toàn tầng giao tiếp xác thực và sinh mã khỏi các dịch vụ nghiệp vụ thông qua các interface tại `common-model`:
1. **`AuthProvider`**:
   - Khai báo hành vi: `authenticate(credentials)`, `refreshToken(token)`, `revokeToken(jti)`, `validate(token)`.
   - Triển khai hiện tại: `DatabaseAuthProvider` (xác thực qua bảng `users` và `BCryptPasswordEncoder`).
   - Khả năng hoán đổi: Khi chuyển sang Keycloak/Okta, chỉ cần tạo `KeycloakAuthProvider` thực hiện gọi token endpoint của IdP mà không chạm vào controller hay business logic.
2. **`TokenProvider`**:
   - Khai báo hành vi: `generateTokens(principal)`, `parseAndValidateToken(token)`, `validateToken(token)`, `getClaims(token)`.
   - Triển khai hiện tại: `JwtTokenProvider` (sử dụng JJWT 0.12.x ký **RS256** và xuất Public Key chuẩn RFC 7517 qua `/.well-known/jwks.json`).
3. **`RoleClaimsAdapter`**:
   - Khai báo: `extractRoles(claims)`.
   - Triển khai mặc định: `DefaultRoleClaimsAdapter` bóc tách linh hoạt từ cả claim `roles`, Keycloak `realm_access.roles`, và OAuth2 `scope`.

### Nguyên tắc 3: Phân quyền Stateless dựa trên Claims/Roles thay vì phụ thuộc DB Users
- Downstream services (`api-service`) sử dụng chuẩn **`spring-boot-starter-oauth2-resource-server`** kết hợp `OidcJwtAuthenticationConverter` (tái sử dụng `RoleClaimsAdapter` từ `common-model`) để xác thực và phân quyền hoàn toàn **Stateless**, không cần duplicate `JwtAuthenticationFilter`:
  - Tự động giải mã token và xác minh chữ ký RS256 thông qua JWKS (`/.well-known/jwks.json`), đọc claims và bóc tách roles vào đối tượng `UserPrincipal`.
  - Đưa `UserPrincipal` kèm `SimpleGrantedAuthority` vào `SecurityContextHolder`.
  - **Tuyệt đối không thực hiện truy vấn bảng `users`** trong quá trình lọc request. Toàn bộ logic `@PreAuthorize("hasRole('CUSTOMER')")` hoặc `principal.isSeller()` được xử lý trong bộ nhớ.

---

## 3. HỆ QUẢ (CONSEQUENCES)

### Điểm tích cực (Positive):
- **Hiệu năng cực cao (Zero DB Overhead)**: Loại bỏ 100% các câu lệnh `SELECT` kiểm tra quyền trên mỗi HTTP request tại các microservice, bảo vệ database core khỏi quá tải.
- **Dễ dàng chuyển đổi IdP**: Đến thời điểm chuyển sang Keycloak/Okta/Auth0, hệ thống chỉ cần đổi cấu hình `issuer`, `jwks-uri` và adapter map role mà không cần can thiệp vào mã nguồn nghiệp vụ của các dịch vụ khác.
- **Tương thích chuẩn quốc tế**: OIDC Token chuẩn giúp tích hợp mượt mà với API Gateway (Spring Cloud Gateway, Kong, Envoy) và các Resource Server của bên thứ ba.
- **Bảo mật phân tán**: Khả năng thu hồi phiên tức thì thông qua tra cứu claim `jti` trên Redis Blacklist tại tầng API Gateway.

### Điểm hạn chế & Thách thức (Negative & Challenges):
- **Độ trễ cập nhật trạng thái người dùng (Status Lag)**: Nếu tài khoản bị khóa (`status = INACTIVE`), token đã cấp phát vẫn có hiệu lực cho đến khi hết hạn (`exp`) hoặc bị thu hồi thủ công (thu hồi qua Redis Blacklist với `jti`). Để giảm thiểu rủi ro, thời gian sống của Access Token được đặt ngắn (1 giờ), kết hợp Refresh Token (7 ngày).

---

## 4. CÁC PHƯƠNG ÁN ĐÃ XEM XÉT (ALTERNATIVES CONSIDERED)
1. **Stateful Session / Query Database Users mỗi Request**: Bác bỏ vì vi phạm nguyên tắc microservices phân tán và gây sụp đổ database khi lưu lượng truy cập tăng vọt.
2. **Hard-code đăng nhập trực tiếp trong Controller/Service**: Bác bỏ vì vi phạm nguyên tắc OCP (Open-Closed Principle), tạo ra nợ kỹ thuật lớn khi chuyển dịch sang Keycloak/Okta trong tương lai.
3. **Sử dụng claims tùy biến phi chuẩn (Custom Non-standard Claims)**: Bác bỏ vì gây khó khăn trong việc kiểm toán, tích hợp API Gateway và không tương thích với các thư viện OAuth2 Resource Server tiêu chuẩn.
