namespace ChattiesClient
{
    partial class LoginForm
    {
        /// <summary>
        ///  Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        ///  Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        ///  Required method for Designer support - do not modify
        ///  the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            label1 = new Label();
            pictureBox1 = new PictureBox();
            txtUsername = new TextBox();
            label2 = new Label();
            label3 = new Label();
            txtPassword = new TextBox();
            btnLogin = new Button();
            label4 = new Label();
            btnRegister = new Button();
            ((System.ComponentModel.ISupportInitialize)pictureBox1).BeginInit();
            SuspendLayout();
            // 
            // label1
            // 
            label1.AutoSize = true;
            label1.Font = new Font("Segoe UI", 18F, FontStyle.Bold, GraphicsUnit.Point, 0);
            label1.Location = new Point(243, 151);
            label1.Name = "label1";
            label1.Size = new Size(308, 41);
            label1.TabIndex = 0;
            label1.Text = "Welcome to Chatties";
            label1.Click += label1_Click;
            // 
            // pictureBox1
            // 
            pictureBox1.BackColor = Color.Transparent;
            pictureBox1.BackgroundImage = Properties.Resources.download;
            pictureBox1.Image = Properties.Resources.download__1_;
            pictureBox1.Location = new Point(292, 0);
            pictureBox1.Name = "pictureBox1";
            pictureBox1.Size = new Size(211, 159);
            pictureBox1.SizeMode = PictureBoxSizeMode.Zoom;
            pictureBox1.TabIndex = 1;
            pictureBox1.TabStop = false;
            pictureBox1.Click += pictureBox1_Click;
            // 
            // txtUsername
            // 
            txtUsername.Font = new Font("Segoe UI", 10.2F, FontStyle.Regular, GraphicsUnit.Point, 0);
            txtUsername.Location = new Point(189, 254);
            txtUsername.Name = "txtUsername";
            txtUsername.Size = new Size(422, 30);
            txtUsername.TabIndex = 3;
            txtUsername.TextChanged += txtUsername_TextChanged;
            // 
            // label2
            // 
            label2.AutoSize = true;
            label2.Font = new Font("Segoe UI", 10.2F, FontStyle.Regular, GraphicsUnit.Point, 0);
            label2.Location = new Point(189, 228);
            label2.Name = "label2";
            label2.Size = new Size(87, 23);
            label2.TabIndex = 4;
            label2.Text = "Username";
            // 
            // label3
            // 
            label3.AutoSize = true;
            label3.Location = new Point(189, 307);
            label3.Name = "label3";
            label3.Size = new Size(80, 23);
            label3.TabIndex = 5;
            label3.Text = "Password";
            // 
            // txtPassword
            // 
            txtPassword.Location = new Point(189, 333);
            txtPassword.Name = "txtPassword";
            txtPassword.Size = new Size(422, 30);
            txtPassword.TabIndex = 6;
            txtPassword.UseSystemPasswordChar = true;
            // 
            // btnLogin
            // 
            btnLogin.BackColor = SystemColors.HotTrack;
            btnLogin.FlatStyle = FlatStyle.Flat;
            btnLogin.Font = new Font("Segoe UI", 10.2F, FontStyle.Bold, GraphicsUnit.Point, 0);
            btnLogin.ForeColor = SystemColors.Control;
            btnLogin.Location = new Point(540, 372);
            btnLogin.Name = "btnLogin";
            btnLogin.Size = new Size(71, 34);
            btnLogin.TabIndex = 7;
            btnLogin.Text = "Login";
            btnLogin.UseVisualStyleBackColor = false;
            btnLogin.Click += btnLogin_Click;
            // 
            // label4
            // 
            label4.AutoSize = true;
            label4.Font = new Font("Segoe UI", 9F, FontStyle.Regular, GraphicsUnit.Point, 0);
            label4.Location = new Point(189, 386);
            label4.Name = "label4";
            label4.Size = new Size(163, 20);
            label4.TabIndex = 8;
            label4.Text = "Don't have an account?";
            label4.Click += label4_Click;
            // 
            // btnRegister
            // 
            btnRegister.AutoSize = true;
            btnRegister.BackColor = Color.Transparent;
            btnRegister.BackgroundImageLayout = ImageLayout.Center;
            btnRegister.Cursor = Cursors.Hand;
            btnRegister.FlatAppearance.BorderColor = Color.FromArgb(0, 0, 0, 0);
            btnRegister.FlatAppearance.MouseDownBackColor = Color.Transparent;
            btnRegister.FlatAppearance.MouseOverBackColor = Color.Transparent;
            btnRegister.FlatStyle = FlatStyle.Flat;
            btnRegister.Font = new Font("Segoe UI", 9F, FontStyle.Regular, GraphicsUnit.Point, 0);
            btnRegister.ForeColor = SystemColors.Highlight;
            btnRegister.Location = new Point(342, 380);
            btnRegister.Name = "btnRegister";
            btnRegister.Size = new Size(108, 32);
            btnRegister.TabIndex = 9;
            btnRegister.Text = "Register here";
            btnRegister.UseVisualStyleBackColor = false;
            btnRegister.Click += btnRegister_Click;
            // 
            // LoginForm
            // 
            AutoScaleDimensions = new SizeF(9F, 23F);
            AutoScaleMode = AutoScaleMode.Font;
            BackColor = SystemColors.ButtonFace;
            ClientSize = new Size(794, 518);
            Controls.Add(label4);
            Controls.Add(btnRegister);
            Controls.Add(btnLogin);
            Controls.Add(txtPassword);
            Controls.Add(label3);
            Controls.Add(label2);
            Controls.Add(txtUsername);
            Controls.Add(pictureBox1);
            Controls.Add(label1);
            Font = new Font("Segoe UI", 10.2F, FontStyle.Regular, GraphicsUnit.Point, 0);
            FormBorderStyle = FormBorderStyle.FixedSingle;
            Name = "LoginForm";
            Text = "Chatties - Login";
            ((System.ComponentModel.ISupportInitialize)pictureBox1).EndInit();
            ResumeLayout(false);
            PerformLayout();
        }

        #endregion

        private Label label1;
        private PictureBox pictureBox1;
        private TextBox txtUsername;
        private Label label2;
        private Label label3;
        private TextBox txtPassword;
        private Button btnLogin;
        private Label label4;
        private Button btnRegister;
        private Label txtU;
    }
}
