using System;
using System.Linq;
using System.Text.RegularExpressions;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Text;
using System.Windows.Forms;

namespace ChattiesClient
{
    public partial class RegisterForm_ : Form
    {
        public RegisterForm_()
        {
            InitializeComponent();
        }

        private void label1_Click(object sender, EventArgs e)
        {

        }

        private void button1_Click_1(object sender, EventArgs e)
        {
            // Lấy dữ liệu và loại bỏ khoảng trắng thừa
            string email = txtEmail.Text.Trim();
            string username = txtUsername.Text.Trim();
            string password = txtPassword.Text;
            string confirm = txtConfirmPassword.Text;

            // 1. Kiểm tra không được để trống bất kỳ ô nào
            if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(username) ||
                string.IsNullOrWhiteSpace(password) || string.IsNullOrWhiteSpace(confirm))
            {
                MessageBox.Show("Please fill in all fields!", "Validation Error", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            // 2. Kiểm tra định dạng Email chuẩn
            if (!Regex.IsMatch(email, @"^[^@\s]+@[^@\s]+\.[^@\s]+$"))
            {
                MessageBox.Show("Invalid email format!", "Validation Error", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            // 3. Kiểm tra Username không chứa ký tự đặc biệt
            if (!username.All(char.IsLetterOrDigit) || !username.Any(char.IsLetter))
            {
                MessageBox.Show("Username must contain at least one letter and no special characters!", "Validation Error", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            // 4. Kiểm tra mật khẩu nhập lại có khớp không
            if (password != confirm)
            {
                MessageBox.Show("Passwords do not match! Please check again.", "Validation Error", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            // Đóng gói dữ liệu thành chuỗi định dạng JSON để sẵn sàng gửi cho C++ Server
            string jsonPayload = $"{{\n  \"action\": \"register\",\n  \"email\": \"{email}\",\n  \"username\": \"{username}\",\n  \"password\": \"{password}\"\n}}";

            MessageBox.Show($"Validation passed! Ready to send JSON to C++ Server:\n\n{jsonPayload}",
                            "Success", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }

        private void btnLogin_Click(object sender, EventArgs e)
        {
            // Khởi tạo và hiển thị lại màn hình Đăng nhập
            LoginForm loginPage = new LoginForm();
            loginPage.Show();

            // Ẩn màn hình Đăng ký hiện tại
            this.Hide();
        }
    }
}
