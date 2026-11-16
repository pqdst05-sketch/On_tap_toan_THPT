# MathTex THPT

Website thư viện đề thi và trò chơi Toán THPT, có khu vực quản lí giáo viên và cổng học sinh dùng mã cá nhân 6 chữ số.

## 1. Đưa website lên GitHub Pages

1. Giải nén bộ nguồn, tải toàn bộ nội dung thư mục `de-thi-toan-thpt` lên repository GitHub (nhánh `main`).
2. Vào **Settings → Pages**, chọn **GitHub Actions** nếu chưa cấu hình.
3. Mỗi lần commit, workflow `.github/workflows/deploy.yml` tự quét thư mục đề/game, tạo `catalog.json` và triển khai website.

## 2. Thêm đề HTML

- Toán 10: `lop10/ten-chu-de/ten-de.html`
- Toán 11: `lop11/ten-chu-de/ten-de.html`
- Toán 12: `lop12/ten-chu-de/ten-de.html`
- Giữ nguyên thư mục CSS, JS, ảnh và đường dẫn tương đối mà đề đang sử dụng.
- Có thể khai báo metadata trong phần `<head>`:

```html
<meta name="exam-title" content="Đề kiểm tra Toán 12 - Chương 1">
<meta name="school" content="Tên trường">
<meta name="school-year" content="2026-2027">
<meta name="description" content="Đề kiểm tra chương 1">
```

Đề sẽ tự xuất hiện trong thư viện sau lần triển khai tiếp theo.

## 3. Thêm trò chơi

Đưa file HTML vào thư mục `games/` hoặc thư mục con. Có thể khai báo `<meta name="game-title" content="Tên trò chơi">` và `description`.

## 4. Bật quản lí lớp, giao đề và lưu bài bằng Supabase

1. Tạo project Supabase.
2. Mở **SQL Editor**, chạy toàn bộ `supabase/schema.sql`.
3. Vào **Project Settings → API**, sao chép Project URL và anon/public key.
4. Điền vào `assets/js/config.js`:

```js
window.MATHTEX_CONFIG = {
  SUPABASE_URL: "https://YOUR-PROJECT.supabase.co",
  SUPABASE_ANON_KEY: "YOUR_SUPABASE_ANON_KEY"
};
```

5. Trong Supabase Authentication, tạo tài khoản cho giáo viên. Sau đó mở `/teacher/` và đăng nhập.
6. Tạo lớp với mã 3 chữ số, ví dụ `121`; nhập Excel/CSV có cột **Họ tên**. Mã học sinh được tạo theo mẫu `121005`.
7. Chọn đề, lớp, thời gian và thời lượng trong mục **Giao đề**. Hệ thống tạo mã giao đề, link và QR.

**Quan trọng:** Không đưa `service_role` key vào website. Chỉ dùng anon/public key; quyền truy cập được giới hạn bằng RLS và RPC trong SQL.

## 5. Tích hợp câu trả lời từ đề HTML

Cổng học sinh tạo lượt làm và nhúng trang đề vào iframe. Để thu thập câu trả lời, file đề cần có các trường nhập với `data-question`, ví dụ:

```html
<label><input type="radio" name="q1" value="A" data-question="Q1"> A</label>
<label><input type="radio" name="q1" value="B" data-question="Q1"> B</label>
<script src="../../assets/js/exam-bridge.js"></script>
```

Điều chỉnh đường dẫn script cho đúng vị trí file HTML. Các câu hỏi hiện tại không có cấu trúc này vẫn có thể mở để xem, nhưng câu trả lời chưa tự động gửi về hệ thống. Bộ nguồn chưa tự động chấm điểm mọi định dạng HTML tùy ý; cần chuẩn hóa mẫu đề và đáp án trước khi bật chấm tự động.

## 6. Phạm vi và bảo mật

- GitHub Pages chỉ lưu nội dung tĩnh; Supabase lưu lớp, học sinh, lượt giao và bài nộp.
- Mã học sinh 6 chữ số là mã nhận diện tiện dụng, không phải mật khẩu bảo mật mạnh. Không dùng nó cho dữ liệu nhạy cảm.
- Với bài kiểm tra cần bảo mật đáp án, không nhúng đáp án/chấm điểm trong HTML công khai. Chuyển đáp án và chấm điểm về máy chủ trước khi sử dụng cho kiểm tra chính thức.
- Kiểm tra thử với một lớp và một đề mẫu trước khi dùng thật.

## 7. Lưu tự động và khôi phục bài làm

- Đề HTML muốn gửi/khôi phục đáp án cần gắn `data-question="Q1"` cho từng ô nhập và nạp `exam-bridge.js`.
- Cổng làm bài đồng bộ câu trả lời lên Supabase sau một khoảng chờ ngắn, và khôi phục các lựa chọn đã lưu khi học sinh tải lại trang.
- Đây là cơ chế lưu câu trả lời, chưa phải chấm điểm tự động. Trường `score` vẫn để trống cho đến khi xây dựng bộ chấm đáp án an toàn phía máy chủ.
- Với câu hỏi tự luận, cần chuẩn hóa trường nhập và quy trình chấm riêng; không nên coi nội dung HTML tùy ý là đáp án có thể chấm tự động.

## 8. Kiểm tra trước khi dùng thật

1. Tạo project Supabase mới và chạy `supabase/schema.sql` một lần.
2. Tạo tài khoản giáo viên trong Supabase Authentication.
3. Điền Project URL và anon/public key vào `assets/js/config.js`.
4. Đăng nhập khu vực giáo viên, tạo thử một lớp có mã 3 chữ số.
5. Nhập danh sách học sinh; kiểm tra mã có đúng 6 chữ số và không trùng trong lớp.
6. Giao một đề mẫu, thử bằng một mã học sinh, làm bài, tải lại trang và kiểm tra câu trả lời được khôi phục.
7. Thử nộp bài và kiểm tra trạng thái trong bảng Bài làm.

Không sử dụng cho bài kiểm tra chính thức có yêu cầu chống gian lận cao cho đến khi hoàn thiện xác thực học sinh mạnh hơn, giới hạn tần suất thử mã, bộ chấm máy chủ và kiểm thử bảo mật.
