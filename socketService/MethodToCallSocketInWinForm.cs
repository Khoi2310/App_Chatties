// 1. Khởi tạo dịch vụ
SocketService chatService = new SocketService();

// 2. Đăng ký sự kiện khi nhận được tin nhắn
chatService.OnMessageReceived += (jsonMessage) => {
    // Lưu ý: Sự kiện này chạy dưới Background Thread của Task.
    // Nếu bạn muốn hiển thị lên UI (TextBox/Listbox), bạn phải dùng Invoke của UI.

    this.Invoke(new Action(() => {
        // Ví dụ phân tích json hoặc hiển thị lên màn hình chat
        txtChatLog.AppendText(jsonMessage + Environment.NewLine);
    }));
};

// 3. Nút bấm Kết nối (Async)
private async void btnConnect_Click(object sender, EventArgs e)
{
    bool isSuccess = await chatService.ConnectAsync("127.0.0.1", 8080);
    if (isSuccess)
    {
        MessageBox.Show("Kết nối thành công!");
    }
}

// 4. Nút bấm Gửi tin nhắn (Async)
private async void btnSend_Click(object sender, EventArgs e)
{
    string jsonPayload = "{\"type\": \"message\", \"channel_id\": 1, \"sender_id\": 10, \"content\": \"hello\"}";
    await chatService.SendMessageAsync(jsonPayload);
}