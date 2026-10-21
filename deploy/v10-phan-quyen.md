# v10 · Phân quyền 4 cấp + sửa lỗi "No reviewers"

> Có 3 việc anh/chị phải tự làm: **(1)** chạy SQL trên Supabase, **(2)** deploy lại mailer trên Apps Script,
> **(3)** merge PR. Claude không truy cập được Supabase / Apps Script nên không tự làm được.
> Làm theo đúng thứ tự dưới đây. Cả quy trình mất khoảng 15 phút.

## Kết quả sau khi làm xong

| Vai trò | Ai | Được làm gì |
|---|---|---|
| **Superadmin** | yen.tran, binh.nguyen, nguyen.che | Xem + sửa mọi thứ, phân quyền cho mọi người, duyệt mọi tài liệu, **export PDF** |
| **Admin** | vy.le, congthanh.bui, phuong.ntl, hoa.doan | **Xem** mọi pillar; **sửa** chỉ ở pillar được Superadmin cấp Edit; vào được Manage access; thêm người mới (Custom/Guest) và chỉ sửa được người do chính mình thêm. Mỗi thay đổi đều được email cho nguyen.che + binh.nguyen |
| **Custom** | các thành viên L&D còn lại | Như hiện tại, **không** thấy Manage access |
| **Guest** | người ngoài team | Chỉ **xem** đúng các tài liệu được share; đăng nhập bằng email |

- **Duyệt (approve):** người duyệt phải có vai trò **cao hơn** người gửi **và** có quyền Edit trên pillar đó
  (Custom → Admin/Superadmin; Admin → Superadmin; Superadmin → Superadmin khác hoặc publish thẳng).
- **Share cho Guest:** editor của tài liệu bấm **Share with guest** trên trang tài liệu; Superadmin nhận email.
- **Lỗi "No reviewers" của chi.dophuong:** nguyên nhân là database chỉ cho non-admin đọc **dòng của chính họ**
  trong bảng members, nên app không có ai để đề xuất làm reviewer. Bước 1 sửa lỗi này.

---

## Bước 1 — Chạy SQL trên Supabase (5 phút)

1. Mở **https://supabase.com/dashboard** → đăng nhập → chọn dự án **L&D Playbook**
   (mã dự án `gwavhbebglgkeihyvsou`).
2. Menu bên trái → **SQL Editor** → **New query**.
3. **Xem trước ai đang là admin** (để biết ai sẽ bị đổi). Dán đoạn sau, bấm **Run**:
   ```sql
   select email, role, admin from public.members order by admin desc, email;
   ```
   Ghi lại những người có `admin = true` **mà không phải** yen.tran / binh.nguyen / nguyen.che.
   Những người này (ví dụ `lnd.edl@pizza4ps.com`) sẽ thành **Custom có Edit trên mọi pillar**
   (vẫn sửa được tài liệu như cũ, nhưng mất quyền Manage access). Sau đó anh/chị chỉnh lại trong Manage access nếu cần.
4. Xoá nội dung ô query, mở file **`deploy/supabase_v10_roles.sql`** trong repo, chép **toàn bộ** và dán vào → **Run**.
   - Thấy `Success. No rows returned` là xong.
   - Nếu thấy lỗi có chữ **"Stop and send this message to the developer"** hoặc bất kỳ lỗi đỏ nào:
     **không làm tiếp**, chụp màn hình gửi Claude. Script chạy trong 1 transaction nên lỗi thì **không có gì bị thay đổi**.
5. Kiểm tra kết quả. Dán đoạn sau → **Run**:
   ```sql
   select email, role, admin, added_by from public.members order by role, email;
   ```
   Phải thấy: 3 người **Superadmin** (`admin = true`), 4 người **Admin**, còn lại là **Custom** hoặc **Guest**.

> Script tự sao lưu bảng members vào `members_backup_v10` trước khi đổi, và chạy lại lần 2 vẫn an toàn.

## Bước 2 — Deploy lại mailer trên Apps Script (5 phút)

Cần làm để Superadmin nhận được email khi Admin đổi quyền / editor share cho Guest.

1. Mở **https://script.google.com** → mở project mailer của L&D Playbook (project đang gửi email duyệt).
2. **Trước khi dán code mới**, copy lại 2 giá trị đang có ở đầu file: **`SHARED_SECRET`** và **`CHAT_WEBHOOK`**.
3. Mở file **`deploy/mailer.gs`** trong repo, chép **toàn bộ** và dán đè lên code cũ.
4. Dán lại `SHARED_SECRET` và `CHAT_WEBHOOK` đã copy ở bước 2 vào 2 dòng đầu.
   (Quên bước này thì **mọi email sẽ ngừng gửi**, kể cả email duyệt.)
5. Kiểm tra dòng `SUPERADMIN_NOTIFY` đã là `['nguyen.che@pizza4ps.com', 'binh.nguyen@pizza4ps.com']`.
6. Bấm **Save** (biểu tượng đĩa mềm).
7. **Deploy** → **Manage deployments** → bấm ✏️ ở Web app hiện có → **Version: New version** → **Deploy**.
   Bắt buộc chọn **New version**, nếu không code mới không có hiệu lực.

## Bước 3 — Merge PR (1 phút)

1. Mở PR trên GitHub (link Claude gửi) → **Merge** (squash).
2. Đợi Vercel deploy xong (~1–2 phút).
3. Mọi người **tải lại trang bằng Ctrl+Shift+R** để lấy bản mới.

---

## Bước 4 — Kiểm tra (5 phút)

| # | Ai làm | Thao tác | Kết quả đúng |
|---|---|---|---|
| 1 | chi.dophuong | Mở PAR → Edit → **Send for approval** | Danh sách reviewer có **phuong.ntl** (và Superadmin) |
| 2 | phuong.ntl | Mở PAR đang chờ duyệt | Thấy nút **Approve / Request changes** |
| 3 | chi.dophuong | Nhìn thanh trên cùng | **Không** có nút Manage access, **không** có nút Export PDF |
| 4 | vy.le | Bấm **Manage access** → chọn chi.dophuong | Mọi nút bị khoá, có dòng "View only" |
| 5 | vy.le | **+ Add** một email test → chọn Custom → bật 1 pillar | Lưu được; nguyen.che và binh.nguyen nhận email trong ~1 phút |
| 6 | Editor bất kỳ | Mở tài liệu mình sửa được → **Share with guest** → nhập email | Superadmin nhận email "Guest share" |
| 7 | nguyen.che | Mở tài liệu | Thấy nút **Export PDF** |

Sau khi test xong, nhớ xoá email test ở mục 5 trong Manage access.

## Gặp sự cố

- **Bước 1 báo lỗi** → không làm tiếp, chụp màn hình gửi Claude (không có gì bị thay đổi).
- **Không có email** ở mục 5/6 → kiểm tra Bước 2: đã dán lại `SHARED_SECRET` chưa, đã chọn **New version** chưa.
- **Admin bấm lưu bị báo "Could not save access"** → đúng thiết kế nếu Admin sửa người không do mình thêm.
  Nếu là người do chính Admin thêm mà vẫn lỗi → gửi Claude ảnh chụp thông báo.
- **Muốn hoàn tác Bước 1:** gửi Claude, đừng tự chạy lệnh hoàn tác ở cuối file SQL.
