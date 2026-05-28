using System.Linq;
namespace ChattiesClient
{
    public partial class LoginForm : Form
    {
        public LoginForm()
        {
            InitializeComponent();
        }

        private void label1_Click(object sender, EventArgs e)
        {

        }

        private void pictureBox1_Click(object sender, EventArgs e)
        {

        }

        private void txtUsername_TextChanged(object sender, EventArgs e)
        {

        }

        private void label4_Click(object sender, EventArgs e)
        {

        }

        private void btnLogin_Click(object sender, EventArgs e)
        {
            // Lấy dữ liệu từ TextBox và loại bỏ các khoảng trắng thừa ở hai đầu bằng hàm Trim()
            string username = txtUsername.Text.Trim();
            string password = txtPassword.Text;

            // Điều kiện 1: Không được để trống cả Username lẫn Password
            if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(password))
            {
                MessageBox.Show("Please enter both username and password!", "Validation Error", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return; // Dừng lại, không chạy tiếp các code bên dưới
            }

            // Điều kiện 2: Username không được chứa ký tự đặc biệt hoặc dấu cách (chỉ lấy chữ và số)
            if (!username.All(char.IsLetterOrDigit))
            {
                MessageBox.Show("Username cannot contain special characters or spaces!", "Validation Error", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            // Điều kiện 3: Username phải chứa ít nhất một chữ cái (không được toàn là số)
            if (!username.Any(char.IsLetter))
            {
                MessageBox.Show("Username must contain at least one letter!", "Validation Error", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            // Đạt toàn bộ điều kiện -> Hiển thị thông báo thành công
            MessageBox.Show($"Validation passed! Attempting to login with: {username}", "Success", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }

        private void btnRegister_Click(object sender, EventArgs e)
        {
            // Tạo một bản sao của màn hình Đăng ký
            RegisterForm_ registerPage = new RegisterForm_();

            // Hiển thị màn hình Đăng ký lên
            registerPage.Show();

            // Giấu màn hình Đăng nhập hiện tại đi
            this.Hide();
        }
    }
}
