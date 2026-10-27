# v12 · Đi vòng qua Vercel khi mạng không tới được Supabase

## Vấn đề
Một số mạng (ví dụ mạng của nguyen.che) không kết nối ổn định tới `*.supabase.co`.
Yêu cầu đăng nhập và đọc dữ liệu bị treo (`net::ERR_TIMED_OUT`), trong khi `lnd-playbook.vercel.app`
vẫn vào được. Đồng nghiệp ở mạng khác thì dùng bình thường.

## Cách hoạt động
- `vercel.json` (đặt ở cả gốc repo và `web/`) chuyển tiếp `https://lnd-playbook.vercel.app/sb/*`
  sang `https://gwavhbebglgkeihyvsou.supabase.co/*`.
- Khi mở app, app gọi thử `/sb/auth/v1/health`:
  - trả lời đúng → **mọi yêu cầu** (đăng nhập, dữ liệu, phân quyền, upload) đi qua `/sb`;
  - không trả lời (chưa cấu hình, chạy ở host khác) → app **tự đi thẳng** như trước.
- Console hiện dòng `[L&D Playbook] Supabase route: proxy` (hoặc `direct`).
- **Realtime** (chuông thông báo và tài liệu tự cập nhật) luôn đi thẳng, vì Vercel không chuyển tiếp
  được WebSocket. Mạng nào chặn Supabase thì chỉ mất phần cập nhật tự động; tải lại trang là thấy mới.
- **Upload file:** thử qua `/sb` trước, lỗi (ví dụ file quá lớn) thì thử thẳng.
  Link lưu vào tài liệu luôn là link gốc `supabase.co`.
- **Phiên đăng nhập được giữ nguyên:** không ai bị đăng xuất khi đổi sang đi qua Vercel.

## Việc anh/chị cần làm

### Bước 1 — Merge PR rồi kiểm tra đường vòng (2 phút)
1. Merge PR → đợi Vercel deploy xong.
2. Mở link sau trên trình duyệt (khoá `apikey` là khoá công khai, vốn đã nằm trong trang web):
   `https://lnd-playbook.vercel.app/sb/auth/v1/health?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd3YXZoYmViZ2xna2VpaHl2c291Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg5MzEzMTcsImV4cCI6MjEwNDUwNzMxN30.0LsDw1aakQZ1XLcQ5oTS4KQNNmKFtDwPWtl8u4RGrfM`
   - Đúng nếu thấy một dòng có `"name":"GoTrue"`.
   - Nếu báo **404 / NOT_FOUND**: Vercel chưa đọc `vercel.json`. Vào Vercel → project `lnd-playbook` →
     **Settings → Build and Deployment → Root Directory**, chụp lại gửi Claude.
     Trong lúc đó app vẫn chạy như cũ (đi thẳng), không ai bị ảnh hưởng.
3. Mở app → **Ctrl+Shift+R** → F12 → Console. Dòng đầu phải là `v2026.10.28c`, tiếp theo là
   `Supabase route: proxy`.

### Bước 2 — Đổi mẫu email đăng nhập (5 phút) · **bắt buộc với mạng bị chặn**
Link trong email đăng nhập mặc định trỏ thẳng tới `supabase.co`, nên mạng bị chặn bấm vào sẽ không
đăng nhập được. Đổi để link trỏ về chính app:

> Bước này cần mở **trang quản trị Supabase**, mà trang đó cũng không vào được từ mạng bị chặn.
> Hãy làm từ **mạng khác** (wifi ở nhà, hoặc hotspot điện thoại của đồng nghiệp), hoặc nhờ một người
> có quyền vào Supabase làm giúp.

1. Supabase → dự án L&D Playbook → **Authentication** → **Emails** (hoặc *Email Templates*).
2. Mở mẫu **Magic Link**. Trong ô nội dung, tìm `{{ .ConfirmationURL }}` và thay bằng:
   ```
   {{ .SiteURL }}?token_hash={{ .TokenHash }}&type=email
   ```
   Chỉ thay đúng phần đó (thường nằm trong `href="…"`), giữ nguyên phần còn lại → **Save**.
3. Làm y hệt với mẫu **Confirm signup** (email gửi cho người đăng nhập lần đầu).
4. Kiểm tra **Authentication → URL Configuration → Site URL** vẫn là `https://lnd-playbook.vercel.app/`.
5. Thử: gửi link đăng nhập cho chính mình → mở email → link phải bắt đầu bằng
   `https://lnd-playbook.vercel.app/?token_hash=…` → bấm vào là vào app.

Link cũ đã gửi trước khi đổi vẫn dùng được ở mạng bình thường.

### Bước 3 — Thử lại trên máy bị lỗi
1. Mở `https://lnd-playbook.vercel.app` → **Ctrl+Shift+R**.
2. Nếu đang kẹt ở màn hình đăng nhập: gửi link mới → bấm link trong email.
3. Phải vào được, thấy đủ tài liệu và nút **Manage access**.

## Lưu ý khi vận hành
- **Giới hạn đăng nhập theo IP:** khi đi qua Vercel, Supabase thấy yêu cầu đến từ IP của Vercel nên
  nhiều người có thể dùng chung một hạn mức đăng nhập theo IP. Với vài chục người dùng nội bộ thì
  không đáng lo. Nếu gặp lỗi *"too many requests"* lúc đăng nhập, tăng giới hạn ở
  Supabase → Authentication → **Rate Limits**.
- **Dữ liệu đi qua Vercel:** nội dung tài liệu (T2) và mã đăng nhập giờ đi qua hạ tầng của Vercel
  (vẫn mã hoá HTTPS ở cả hai chặng). Vercel vốn đang host app, nhưng trước đây chỉ phục vụ file trang
  web. Nên báo **Technology & Innovation** để họ nắm Vercel giờ là một bên xử lý dữ liệu trên đường
  truyền (DPA với Vercel nếu chính sách yêu cầu).
- **Gỡ bỏ:** xoá 2 file `vercel.json` là app tự quay về đi thẳng. Không cần sửa code.
