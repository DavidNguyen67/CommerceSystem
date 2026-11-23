# ADR-006: ĐỊNH NGHĨA TABLE ENTITY VÀ QUẢN LÝ DATABASE MIGRATION TẬP TRUNG TẠI COMMON-MODEL
**Trạng thái:** ACCEPTED  
**Ngày quyết định:** 2026-11-23  
**Người quyết định:** Architecture & Engineering Team  

---

## 1. BỐI CẢNH (CONTEXT)
Trong kiến trúc phân tán microservices của CommerceFlow, hệ thống ban đầu phân tách schema logic theo từng Bounded Context (Customer, Seller, Product, Inventory, Order, Saga, Payment, Promotion, Shipping, Review). Tuy nhiên, trong quá trình phát triển đa dự án (multi-module Maven bundle gồm `api-service`, `event-consumer`, `saga-orchestrator`, `job-service`...):
1. Các microservice bắt đầu tự định nghĩa lại các Entity trùng lặp (`InventoryEntity`, `ShipmentEntity`, `SagaInstanceEntity`...), gây lãng phí mã nguồn và phát sinh lỗi sai lệch kiểu dữ liệu hoặc sai lệch import package.
2. Các tệp Flyway migration bị phân tán rải rác trong từng service (`api-service`, `event-consumer`, `saga-orchestrator`), gây khó khăn cho việc quản lý phiên bản database tập trung, triển khai CI/CD và tiềm ẩn nguy cơ Schema Drift (lệch cấu trúc bảng giữa các môi trường).

Chúng tôi cần một quyết định kiến trúc rõ ràng về vai trò của module `common-model` trong việc định nghĩa cấu trúc bảng và quản lý tiến hóa cơ sở dữ liệu.

---

## 2. QUYẾT ĐỊNH (DECISION)
Chúng tôi quyết định chọn **`common-model` là Single Source of Truth** cho việc **định nghĩa Table Entities** và **quản lý/thực thi Database Migration**:
1. **Định nghĩa Table Entities**:
   - Tất cả các thực thể JPA (`@Entity`) đại diện cho bảng dữ liệu của toàn bộ 10 Bounded Contexts được định nghĩa tập trung tại `common-model/src/main/java/com/commerce/common_model/entity/`.
   - Các microservice (`api-service`, `event-consumer`, `saga-orchestrator`...) loại bỏ hoàn toàn các Entity cục bộ, thay vào đó import và tái sử dụng trực tiếp các Entity từ `com.commerce.common_model.entity.*`.
   - Các Spring Boot Application cấu hình `@EntityScan(basePackages = "com.commerce.common_model.entity")` để kích hoạt ORM mapping.
2. **Quản lý & Thực thi Database Migration**:
   - Toàn bộ các script Flyway DDL migration theo chuẩn versioning (`V1__init_customer_identity_schema.sql` đến `V10__init_review_schema.sql`) được quy hoạch tập trung duy nhất tại `common-model/src/main/resources/db/migration/`.
   - Cấu hình `flyway-maven-plugin` trong `common-model/pom.xml` cho phép thực thi migration độc lập qua lệnh:
     ```bash
     mvn flyway:migrate -pl common-model
     ```
   - Cung cấp class `DatabaseMigrationRunner` để có thể chạy migration bằng Java hoặc tích hợp tự động trong pipeline CI/CD trước khi deploy các microservice applications.

---

## 3. HỆ QUẢ (CONSEQUENCES)

### Điểm tích cực (Positive):
- **Triệt tiêu Schema Drift**: Toàn bộ cấu trúc bảng và lịch sử thay đổi DDL được quản lý thống nhất tại một nơi, đảm bảo môi trường Dev, Staging và Production luôn đồng bộ 100%.
- **DRY (Don't Repeat Yourself)**: Không còn hiện tượng các module định nghĩa trùng lặp class entity hoặc enum dẫn đến compile failure hay mismatch kiểu dữ liệu.
- **Tiện lợi cho CI/CD & Database Administrator (DBA)**: DBA và pipeline chỉ cần chạy migration một lần duy nhất từ `common-model` thay vì phải chạy script phân tán ở từng microservice.
- **Tính tự trị của dịch vụ vẫn được bảo toàn**: Mặc dù table definition và migration tập trung ở `common-model`, mỗi microservice tại runtime vẫn tuân thủ nguyên tắc chỉ thao tác với các Repository và bảng thuộc thẩm quyền Bounded Context của mình.

### Điểm hạn chế & Rủi ro (Negative & Risks):
- Thay đổi cấu trúc bảng đòi hỏi cập nhật `common-model` và build lại thư viện trước khi microservice sử dụng. (Điều này được kiểm soát tốt thông qua Maven multi-module dependency).

---

## 4. CÁC PHƯƠNG ÁN ĐÃ XEM XÉT (ALTERNATIVES CONSIDERED)
- **Migration và Entity phân tán hoàn toàn theo từng Microservice**: Bác bỏ vì gây trùng lặp mã nguồn nghiêm trọng, khó đồng bộ phiên bản migration khi triển khai và thường xuyên xảy ra lỗi lệch schema giữa các team phát triển.
- **Tách riêng một module database-migration thuần túy**: Bác bỏ vì việc tích hợp chung trong `common-model` tạo sự gắn kết chặt chẽ (cohesion) giữa JPA Entity và DDL SQL Script tương ứng, giúp developer dễ dàng đối soát khi thay đổi field.
