# MA TRẬN QUY TẮC NGHIỆP VỤ (BUSINESS RULES MATRIX)
**Dự án:** CommerceFlow Enterprise Multi-vendor Marketplace  
**Kiến trúc:** Microservices & Cross-Domain Business Invariants  
**Phiên bản:** 2.0.0 (Comprehensive Multi-vendor Marketplace)  

---

## 1. QUY TẮC ĐẶT HÀNG & GIỎ HÀNG (ORDER & CART RULES)

| Mã quy tắc | Tên quy tắc | Nội dung chi tiết | Hành động khi vi phạm |
|---|---|---|---|
| **BR-ORD-001** | Max Items Per Checkout | Một giỏ hàng chỉ được phép checkout tối đa 50 mặt hàng (SKU) và từ tối đa 10 Seller khác nhau trong một lần đặt lệnh. | Hệ thống từ chối Checkout, yêu cầu người dùng tách bớt đơn hàng (`HTTP 400 Bad Request`). |
| **BR-ORD-002** | Price Invariant Verification | Giá của từng sản phẩm tại thời điểm bấm Checkout phải được tái xác thực với cơ sở dữ liệu Product Catalog. Không chấp nhận giá do Client gửi lên. | Nếu giá thay đổi so với giỏ hàng: Cảnh báo người dùng và cập nhật lại giỏ hàng (`HTTP 409 Conflict`). |
| **BR-ORD-003** | Seller Status Guard | Khách hàng không thể đặt mua hàng từ Seller có trạng thái `SUSPENDED`, `INACTIVE` hoặc đang bật chế độ `VACATION_MODE`. | Từ chối tạo Sub-Order cho Seller đó. |
| **BR-ORD-004** | Self-Purchase Prohibition | Tài khoản Seller không được phép đặt mua sản phẩm do chính gian hàng của mình đăng bán (Chống gian lận tăng đơn ảo). | Chặn checkout ngay tại bước thẩm định nghiệp vụ (`HTTP 403 Forbidden`). |
| **BR-ORD-005** | Order Expiration TTL | Đơn hàng thông thường có thời hạn thanh toán là 15 phút. Đơn hàng có chứa sản phẩm Flash Sale có thời hạn thanh toán là 3 phút. | Nếu quá hạn: Scheduler kích hoạt lệnh hủy đơn và nhả tồn kho tự động. |

---

## 2. QUY TẮC TRƯNG BÀY & SẢN PHẨM (CATALOG & PRODUCT RULES)

| Mã quy tắc | Tên quy tắc | Nội dung chi tiết | Hành động khi vi phạm |
|---|---|---|---|
| **BR-CAT-001** | Minimum Media Requirement | Một sản phẩm SPU khi đăng bán bắt buộc phải có tối thiểu 1 ảnh đại diện chính (Primary Thumbnail) và độ phân giải tối thiểu 500x500px. | Từ chối lưu SPU và trả về mã lỗi `422 Unprocessable Entity`. |
| **BR-CAT-002** | Mandatory SKU Generation | Nếu sản phẩm bật chế độ phân loại hàng (Options), mỗi tổ hợp thuộc tính phải sinh ra đúng 1 SKU tương ứng. Giá bán của SKU không được chênh lệch quá 5 lần giữa các biến thể trong cùng 1 SPU (Chống lừa đảo giật tít giá ảo). | Từ chối đăng bán nếu tỷ lệ giá giữa SKU rẻ nhất và đắt nhất vượt ngưỡng quy định. |
| **BR-CAT-003** | Shopee Mall Verification | Chỉ các gian hàng được cấp nhãn `MALL` mới được phép gắn thương hiệu nằm trong danh mục `brands.is_mall_brand = true`. | Shop thường đăng bán hàng hiệu bắt buộc phải qua khâu kiểm duyệt chứng từ nguồn gốc. |
| **BR-CAT-004** | Out-of-Stock Display Behavior | Khi toàn bộ các SKU của một SPU có tồn kho khả dụng bằng 0, sản phẩm vẫn hiển thị trên trang tìm kiếm nhưng bị gắn cờ "Hết Hàng" và vô hiệu hóa nút "Thêm vào giỏ" / "Mua ngay". | Cập nhật cờ hiển thị thời gian thực qua Redis Cache. |

---

## 3. QUY TẮC QUẢN LÝ TỒN KHO (INVENTORY RULES)

| Mã quy tắc | Tên quy tắc | Nội dung chi tiết | Hành động khi vi phạm |
|---|---|---|---|
| **BR-INV-001** | Non-Negative Stock | Tồn kho khả dụng (`available_quantity = physical_quantity - reserved_quantity`) không bao giờ được phép nhỏ hơn 0. | Lệnh giữ hàng (Reservation) bị từ chối ngay lập tức với lỗi `OUT_OF_STOCK`. |
| **BR-INV-002** | Atomic Reservation | Việc kiểm tra và tăng `reserved_quantity` phải được thực hiện nguyên tử (Atomic). Tuyệt đối không đọc trước rồi cập nhật sau bằng 2 câu lệnh tách rời. | Sử dụng Redis Lua Script hoặc Database Conditional Update. |
| **BR-INV-003** | Reservation Timeout Rollback | Mọi bản ghi khóa tồn kho (`inventory_reservations`) bắt buộc phải có trường `expires_at`. Khi quá hạn mà không nhận được tín hiệu `COMMIT`, tồn kho phải được hoàn trả về `available_quantity`. | Background Sweeper Worker quét và trả hàng tự động. |
| **BR-INV-004** | Return to Stock Condition | Hàng trả về do giao thất bại (Delivery Failure) được tự động hoàn lại tồn kho khả dụng. Hàng khách khiếu nại trả về (Customer Return) phải qua bước kiểm tra chất lượng (QC Passed) của Seller mới được cộng lại vào kho. | Phân loại trạng thái kho: `DAMAGED_HOLD` vs `AVAILABLE`. |

---

## 4. QUY TẮC THANH TOÁN & DÒNG TIỀN (PAYMENT & ESCROW RULES)

| Mã quy tắc | Tên quy tắc | Nội dung chi tiết | Hành động khi vi phạm |
|---|---|---|---|
| **BR-PAY-001** | Single Payment Per Parent Order | Mỗi Parent Order chỉ gắn liền với 1 giao dịch thanh toán thành công duy nhất. Không hỗ trợ chia nhỏ thanh toán nhiều lần cho 1 Parent Order. | Khóa giao dịch bằng Idempotency Key tại tầng Payment Gateway. |
| **BR-PAY-002** | Payment Amount Strict Match | Số tiền thanh toán thực tế ghi nhận từ Webhook của Cổng thanh toán phải trùng khớp chính xác 100% với `total_amount` của Parent Order. | Nếu số tiền không khớp: Treo trạng thái `PAYMENT_DISCREPANCY`, kích hoạt cảnh báo gian lận và thông báo đối soát. |
| **BR-PAY-003** | Late Payment Webhook Handling | Nếu Webhook thanh toán thành công gửi đến sau khi đơn hàng đã bị `EXPIRED` (quá hạn) và kho đã bị giải phóng: Hệ thống không được xác nhận đơn mà phải chuyển sang quy trình **Tự động hoàn tiền (Auto-Refund)** cho khách. | Tránh tình trạng nhận tiền của khách nhưng không còn hàng để giao. |
| **BR-PAY-004** | Escrow Holding Period | Toàn bộ tiền hàng của Sub-Order (sau khi trừ phí sàn) được giữ trong tài khoản Escrow tối thiểu 3 ngày sau khi đơn vị vận chuyển xác nhận `DELIVERED`. | Seller chỉ được rút tiền khi trạng thái chuyển sang `SETTLED`. |

---

## 5. QUY TẮC KHUYẾN MÃI & VOUCHER (PROMOTION RULES)

| Mã quy tắc | Tên quy tắc | Nội dung chi tiết | Hành động khi vi phạm |
|---|---|---|---|
| **BR-PRO-001** | Dual-tier Voucher Stacking | Trong cùng một lần Checkout, khách hàng được phép áp dụng tối đa: 1 Voucher Miễn Phí Vận Chuyển + 1 Voucher Giảm Giá Sàn + 1 Voucher Riêng của từng Shop. | Chặn nếu người dùng cố tình gửi nhiều voucher cùng một danh mục phân loại. |
| **BR-PRO-002** | Budget Limit Invariant | Tổng giá trị chiết khấu đã giải ngân của một Campaign không được vượt quá ngân sách (`total_budget`) được phê duyệt. | Đóng mã voucher ngay khi ngân sách chạm ngưỡng. |
| **BR-PRO-003** | Pro-Rata Voucher Discount Allocation | Khi áp dụng voucher toàn sàn trên giỏ hàng đa người bán, giá trị giảm giá được phân bổ theo tỷ lệ giá trị hàng của từng Sub-Order: $\text{Discount}_i = \text{TotalDiscount} \times \frac{\text{SubOrderValue}_i}{\text{TotalOrderValue}}$. | Đảm bảo tính toán công bằng phần chiết khấu khi có yêu cầu hủy lẻ một Sub-Order. |
| **BR-PRO-004** | Voucher Rollback on Full Cancellation | Nếu toàn bộ đơn hàng bị hủy trước khi giao, mã voucher sẽ được hoàn lại quyền sử dụng cho khách hàng (nếu voucher còn trong thời hạn hiệu lực). | Kích hoạt Compensation Command trả lại voucher usage counter. |

---

## 6. QUY TẮC VẬN CHUYỂN & ĐÁNH GIÁ (LOGISTICS & REVIEW RULES)

| Mã quy tắc | Tên quy tắc | Nội dung chi tiết | Hành động khi vi phạm |
|---|---|---|---|
| **BR-SHIP-001** | Default Pickup Warehouse | Người bán phải có ít nhất 1 địa chỉ kho lấy hàng (`PICKUP`) đang kích hoạt mới được phép chuyển trạng thái đơn hàng sang `READY_TO_SHIP`. | Yêu cầu người bán hoàn tất cài đặt địa chỉ lấy hàng trước khi xử lý đơn. |
| **BR-SHIP-002** | Package Weight & Size Limit | Kiện hàng đóng gói cho đơn vị vận chuyển tiêu chuẩn không được vượt quá 30kg và kích thước chiều dài nhất không vượt quá 150cm. | Hệ thống bắt buộc người bán phải chọn phương thức Vận chuyển Hàng cồng kềnh (Heavy Cargo). |
| **BR-REV-001** | Review Eligibility & Window | Khách hàng chỉ có thể đánh giá sản phẩm sau khi đơn chuyển sang `DELIVERED` và trong vòng tối đa 30 ngày kể từ ngày nhận hàng. | Ẩn nút đánh giá khi đã quá thời hạn 30 ngày. |
| **BR-REV-002** | Single Review Per Item | Mỗi `order_item_id` chỉ được đánh giá 1 lần duy nhất. Khách hàng được phép chỉnh sửa đánh giá 1 lần trong vòng 30 ngày. | Chặn request tạo đánh giá mới nếu đã có bản ghi tồn tại. |
| **BR-REV-003** | Profanity & Spam Filter | Bình luận chứa các từ khóa cấm, số điện thoại spam hoặc ký tự vô nghĩa sẽ tự động bị ẩn (`is_hidden = true`) và đưa vào hàng đợi kiểm duyệt của Admin. | Áp dụng thuật toán Regex & Machine Learning text filtering trước khi lưu DB. |
