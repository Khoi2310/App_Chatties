using System.Diagnostics;

namespace ChattiesClient
{
    [DebuggerDisplay($"{{{nameof(GetDebuggerDisplay)}(),nq}}")]
    partial class RegisterForm_
    {
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// Clean up any resources being used.
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
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            pictureBox1 = new PictureBox();
            label1 = new Label();
            label2 = new Label();
            label3 = new Label();
            label4 = new Label();
            label5 = new Label();
            txtPassword = new TextBox();
            txtEmail = new TextBox();
            txtUsername = new TextBox();
            button1 = new Button();
            btnLogin = new Button();
            txtConfirmPassword = new TextBox();
            ((System.ComponentModel.ISupportInitialize)pictureBox1).BeginInit();
            SuspendLayout();
            // 
            // pictureBox1
            // 
            pictureBox1.BackColor = Color.Transparent;
            pictureBox1.Image = Properties.Resources.download;
            pictureBox1.Location = new Point(0, 1);
            pictureBox1.Name = "pictureBox1";
            pictureBox1.Size = new Size(153, 153);
            pictureBox1.SizeMode = PictureBoxSizeMode.Zoom;
            pictureBox1.TabIndex = 0;
            pictureBox1.TabStop = false;
            // 
            // label1
            // 
            label1.AutoSize = true;
            label1.Font = new Font("Segoe UI", 18F, FontStyle.Bold, GraphicsUnit.Point, 0);
            label1.Location = new Point(312, 67);
            label1.Name = "label1";
            label1.Size = new Size(269, 41);
            label1.TabIndex = 1;
            label1.Text = "Create an account";
            label1.Click += label1_Click;
            // 
            // label2
            // 
            label2.AutoSize = true;
            label2.Location = new Point(258, 136);
            label2.Name = "label2";
            label2.Size = new Size(51, 23);
            label2.TabIndex = 2;
            label2.Text = "Email";
            // 
            // label3
            // 
            label3.AutoSize = true;
            label3.Location = new Point(258, 211);
            label3.Name = "label3";
            label3.Size = new Size(87, 23);
            label3.TabIndex = 3;
            label3.Text = "Username";
            // 
            // label4
            // 
            label4.AutoSize = true;
            label4.Location = new Point(258, 286);
            label4.Name = "label4";
            label4.Size = new Size(80, 23);
            label4.TabIndex = 4;
            label4.Text = "Password";
            // 
            // label5
            // 
            label5.AutoSize = true;
            label5.Location = new Point(258, 357);
            label5.Name = "label5";
            label5.Size = new Size(141, 23);
            label5.TabIndex = 5;
            label5.Text = "ConfirmPassword";
            // 
            // txtPassword
            // 
            txtPassword.Location = new Point(258, 308);
            txtPassword.Name = "txtPassword";
            txtPassword.Size = new Size(374, 30);
            txtPassword.TabIndex = 7;
            txtPassword.UseSystemPasswordChar = true;
            // 
            // txtEmail
            // 
            txtEmail.Location = new Point(258, 162);
            txtEmail.Name = "txtEmail";
            txtEmail.Size = new Size(374, 30);
            txtEmail.TabIndex = 8;
            // 
            // txtUsername
            // 
            txtUsername.Location = new Point(258, 237);
            txtUsername.Name = "txtUsername";
            txtUsername.Size = new Size(374, 30);
            txtUsername.TabIndex = 9;
            // 
            // button1
            // 
            button1.AutoSize = true;
            button1.BackColor = SystemColors.HotTrack;
            button1.FlatAppearance.BorderColor = Color.FromArgb(0, 0, 0, 0);
            button1.FlatStyle = FlatStyle.Flat;
            button1.Font = new Font("Segoe UI", 12F, FontStyle.Bold, GraphicsUnit.Point, 0);
            button1.ForeColor = SystemColors.Control;
            button1.Location = new Point(315, 435);
            button1.Name = "button1";
            button1.Size = new Size(263, 40);
            button1.TabIndex = 10;
            button1.Text = "Create Account";
            button1.UseVisualStyleBackColor = false;
            button1.Click += button1_Click_1;
            // 
            // btnLogin
            // 
            btnLogin.BackColor = Color.Transparent;
            btnLogin.Cursor = Cursors.Hand;
            btnLogin.FlatAppearance.BorderColor = Color.FromArgb(0, 0, 0, 0);
            btnLogin.FlatAppearance.MouseDownBackColor = Color.Transparent;
            btnLogin.FlatAppearance.MouseOverBackColor = Color.Transparent;
            btnLogin.FlatStyle = FlatStyle.Flat;
            btnLogin.Font = new Font("Segoe UI", 9F, FontStyle.Regular, GraphicsUnit.Point, 0);
            btnLogin.ForeColor = SystemColors.HotTrack;
            btnLogin.Location = new Point(258, 481);
            btnLogin.Name = "btnLogin";
            btnLogin.Size = new Size(237, 29);
            btnLogin.TabIndex = 11;
            btnLogin.Text = "Already have an account? Login\r\n";
            btnLogin.UseVisualStyleBackColor = false;
            btnLogin.Click += btnLogin_Click;
            // 
            // txtConfirmPassword
            // 
            txtConfirmPassword.Location = new Point(258, 383);
            txtConfirmPassword.Name = "txtConfirmPassword";
            txtConfirmPassword.Size = new Size(374, 30);
            txtConfirmPassword.TabIndex = 12;
            txtConfirmPassword.UseSystemPasswordChar = true;
            // 
            // RegisterForm_
            // 
            AutoScaleDimensions = new SizeF(9F, 23F);
            AutoScaleMode = AutoScaleMode.Font;
            ClientSize = new Size(893, 597);
            Controls.Add(txtConfirmPassword);
            Controls.Add(btnLogin);
            Controls.Add(button1);
            Controls.Add(txtUsername);
            Controls.Add(txtEmail);
            Controls.Add(txtPassword);
            Controls.Add(label5);
            Controls.Add(label4);
            Controls.Add(label3);
            Controls.Add(label2);
            Controls.Add(label1);
            Controls.Add(pictureBox1);
            Font = new Font("Segoe UI", 10.2F, FontStyle.Regular, GraphicsUnit.Point, 0);
            Name = "RegisterForm_";
            Text = "RegisterForm_";
            ((System.ComponentModel.ISupportInitialize)pictureBox1).EndInit();
            ResumeLayout(false);
            PerformLayout();
        }

        #endregion

        private PictureBox pictureBox1;
        private Label label1;
        private Label label2;
        private Label label3;
        private Label label4;
        private Label label5;
        private TextBox ttxtConfirmPassword;
        private TextBox txtPassword;
        private TextBox txtEmail;
        private TextBox txtUsername;
        private Button button1;
        private Button btnLogin;

        private string GetDebuggerDisplay()
        {
            return ToString();
        }

        private TextBox txtConfirmPassword;
    }
}