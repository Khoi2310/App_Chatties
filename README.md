# 🖥️ Chatties Client - Giao Diện Người Dùng (WinForms)

Đây là mã nguồn phần Client của hệ thống Chat, được thiết kế trên nền tảng .NET Windows Forms (C#).

## 📂 Cấu Trúc File Quan Trọng
- **`Program.cs`**: Điểm bắt đầu của ứng dụng, thiết lập cấu hình và gọi màn hình Đăng nhập (LoginForm) đầu tiên.
- **`ChattiesClient.csproj`**: File cấu hình dự án chứa thông tin phiên bản .NET và các tài nguyên đi kèm.
- **`LoginForm.cs` & `RegisterForm.cs`**: Chứa code logic xử lý dữ liệu, kiểm tra tính hợp lệ (Validation) và đóng gói JSON gửi đi.
- **Thư mục `Resources/`**: Nơi lưu trữ toàn bộ hình ảnh, icon được sử dụng trên giao diện.

## 🚀 Cách Cài Đặt Và Chạy (Dành cho thành viên team)
1. Tải toàn bộ mã nguồn về máy.
2. Đảm bảo máy đã cài đặt **Visual Studio 2022** (hỗ trợ .NET C#).
3. Mở file `ChattiesClient.slnx` hoặc `ChattiesClient.csproj` bằng Visual Studio.
4. Nhấn **F5** hoặc nút **Start** màu xanh lá cây để khởi chạy giao diện.

## 🛠️ Chức năng hiện tại
- [x] Thiết kế UI Đăng nhập.
- [x] Thiết kế UI Đăng ký.
- [x] Cảnh báo lỗi nhập liệu trống, sai định dạng Email, sai Mật khẩu.
- [x] Khởi tạo gói dữ liệu JSON mô phỏng chuẩn bị gửi đi.