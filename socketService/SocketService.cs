using System;
using System.IO;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

public class SocketService
{
    private TcpClient _tcpClient;
    private NetworkStream _stream;
    private StreamReader _reader;
    private StreamWriter _writer;
    private CancellationTokenSource _cts;
    private bool _isConnected;

    // Event kích hoạt khi nhận được tin nhắn từ Server
    public event Action<string> OnMessageReceived;

    // Event kích hoạt khi trạng thái kết nối thay đổi (tùy chọn, giúp cập nhật UI)
    public event Action<bool> OnConnectionStatusChanged;

    public bool IsConnected => _isConnected;

    /// <summary>
    /// Kết nối bất đồng bộ tới Server
    /// </summary>
    public async Task<bool> ConnectAsync(string host, int port)
    {
        if (_isConnected) return true;

        try
        {
            _tcpClient = new TcpClient();
            _cts = new CancellationTokenSource();

            // Kết nối bất đồng bộ không làm treo UI
            await _tcpClient.ConnectAsync(host, port);

            _stream = _tcpClient.GetStream();

            // Khởi tạo Reader/Writer với UTF-8 để tránh lỗi font tiếng Việt
            _reader = new StreamReader(_stream, Encoding.UTF8);
            _writer = new StreamWriter(_stream, new UTF8Encoding(false)) { AutoFlush = true };

            _isConnected = true;
            OnConnectionStatusChanged?.Invoke(true);

            // Chạy luồng đọc dữ liệu ngầm (Fire and Forget)
            _ = ReceiveLoopAsync(_cts.Token);

            return true;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Connect Error]: {ex.Message}");
            Disconnect();
            return false;
        }
    }

    /// <summary>
    /// Luồng đọc dữ liệu liên tục chạy ngầm sử dụng async/await
    /// </summary>
    private async Task ReceiveLoopAsync(CancellationToken cancellationToken)
    {
        try
        {
            while (!cancellationToken.IsCancellationRequested && _tcpClient.Connected)
            {
                // Đọc dữ liệu theo dòng (chờ cho đến khi gặp ký tự '\n')
                // Hàm này sẽ treo ngầm (await) cho đến khi có dữ liệu, không hề block UI Thread
                string response = await _reader.ReadLineAsync();

                if (response == null)
                {
                    // Server chủ động ngắt kết nối (EOF)
                    Console.WriteLine("[Client] Server closed connection.");
                    break;
                }

                if (!string.IsNullOrWhiteSpace(response))
                {
                    // Bắn sự kiện ra ngoài giao diện xử lý (ví dụ: Parse JSON)
                    // Sử dụng Invoke để an toàn hơn
                    OnMessageReceived?.Invoke(response);
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Receive Error]: {ex.Message}");
        }
        finally
        {
            // Tự động dọn dẹp và báo ngắt kết nối nếu vòng lặp kết thúc (do lỗi hoặc mất mạng)
            Disconnect();
        }
    }

    /// <summary>
    /// Gửi tin nhắn JSON lên Server bất đồng bộ
    /// </summary>
    public async Task SendMessageAsync(string json)
    {
        if (!_isConnected || _writer == null)
        {
            throw new InvalidOperationException("Chưa kết nối đến Server.");
        }

        try
        {
            // Viết dữ liệu kèm ký tự xuống dòng '\n' để Server Boost::Asio nhận biết được kết thúc gói
            await _writer.WriteLineAsync(json);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Send Error]: {ex.Message}");
            Disconnect();
            throw;
        }
    }

    /// <summary>
    /// Ngắt kết nối và giải phóng tài nguyên an toàn
    /// </summary>
    public void Disconnect()
    {
        if (!_isConnected) return;

        try
        {
            _cts?.Cancel(); // Hủy vòng lặp nhận dữ liệu

            _reader?.Dispose();
            _writer?.Dispose();
            _stream?.Dispose();
            _tcpClient?.Close();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Disconnect Error]: {ex.Message}");
        }
        finally
        {
            _isConnected = false;
            OnConnectionStatusChanged?.Invoke(false);
            Console.WriteLine("[Client] Disconnected from server.");
        }
    }
}