#include <iostream>
#include <queue>
#include <mutex>
#include <vector>
#include <portaudio.h>

// Cấu hình các tham số âm thanh theo yêu cầu
const int SAMPLE_RATE = 48000;
const int FRAMES_PER_BUFFER = 480; // 480 frames tại 48kHz tương đương 10ms độ trễ (chuẩn cho Voice Chat)
const int NUM_CHANNELS = 1;        // Mono

// ==========================================
// 1. THÀNH PHẦN QUẢN LÝ HÀNG ĐỢI ÂM THANH (Thread-safe Queue)
// ==========================================
class AudioQueue {
public:
    void push(const std::vector<float>& frame) {
        std::lock_guard<std::mutex> lock(mutex_);
        queue_.push(frame);
    }

    bool pop(std::vector<float>& frame) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (queue_.empty()) return false;
        frame = std::move(queue_.front());
        queue_.pop();
        return true;
    }

    bool empty() {
        std::lock_guard<std::mutex> lock(mutex_);
        return queue_.empty();
    }

private:
    std::queue<std::vector<float>> queue_;
    std::mutex mutex_;
};

// Cấu trúc chứa dữ liệu truyền vào Callback
struct AudioUserData {
    AudioQueue* recordQueue;
    // Bạn có thể thêm hàng đợi Playback vào đây nếu muốn nhận dữ liệu từ mạng về để phát ra loa
};

// ==========================================
// 2. NƠI MÃ HÓA ÂM THANH (FFmpeg / libopus Placeholder)
// ==========================================
void encodeAndSendAudio(const std::vector<float>& rawAudio) {
    // ------------------------------------------------------------------
    // PLACEHOLDER: NƠI BẠN CHÈN CODE MÃ HÓA (OPUS / FFMPEG)
    // ------------------------------------------------------------------
    // Ví dụ tiến trình xử lý tại đây:
    // 1. Khởi tạo OpusEncoder (nếu chưa có): opus_encoder_encode_float(...)
    // 2. Truyền mảng dữ liệu rawAudio.data() vào hàm mã hóa của Opus.
    // 3. Opus sẽ trả về một mảng các byte đã nén (thường chỉ vài chục tới trăm bytes).
    // 4. Lấy gói tin đã nén đó đóng vào chuỗi JSON hoặc mảng Byte và gọi:
    //    SocketService::SendMessageAsync() hoặc gửi qua UDP Socket để truyền đi.
    // ------------------------------------------------------------------

    // Tạm thời in ra log giả lập để kiểm tra hoạt động
    static int packetCount = 0;
    if (++packetCount % 100 == 0) { // Cứ 100 gói (khoảng 1 giây) in log 1 lần
        std::cout << "[Opus Encoder Placeholder] Đang xử lý gói âm thanh thứ "
            << packetCount << " | Kích thước mẫu: " << rawAudio.size() << " samples.\n";
    }
}

// ==========================================
// 3. PORTAUDIO CALLBACK HÀM (Chạy trên Thread riêng của Hệ điều hành)
// ==========================================
static int paCallback(const void* inputBuffer, void* outputBuffer,
    unsigned long framesPerBuffer,
    const PaStreamCallbackTimeInfo* timeInfo,
    PaStreamCallbackFlags statusFlags,
    void* userData)
{
    const float* in = (const float*)inputBuffer;
    float* out = (float*)outputBuffer;
    AudioUserData* data = (AudioUserData*)userData;

    // A. Thu âm (Input) từ Microphone
    if (in != nullptr) {
        // Tạo một vector chứa các mẫu âm thanh thô (Float32) của buffer hiện tại
        std::vector<float> recordedFrame(in, in + framesPerBuffer);

        // Đẩy vào hàng đợi để thread khác lấy ra mã hóa (tránh block callback mạng)
        data->recordQueue->push(recordedFrame);
    }

    // B. Phát âm thanh (Output) ra Loa
    if (out != nullptr) {
        // Trong ứng dụng Voice Chat: Bạn sẽ lấy dữ liệu giải mã (decoded) từ mạng về để đổ vào `out`
        // Ở đây chúng ta tạm thời ngắt tiếng (Mute) hoặc cho phát lại chính tiếng micro (Loopback) để test.
        for (unsigned int i = 0; i < framesPerBuffer; i++) {
            if (in != nullptr) {
                out[i] = in[i]; // Loopback: Nói vào mic tự nghe lại ở loa
            }
            else {
                out[i] = 0.0f;  // Mute nếu không có input
            }
        }
    }

    return paContinue;
}

// ==========================================
// 4. HÀM MAIN VÀ QUẢN LÝ VÒNG ĐỜI STREAM
// ==========================================
int main() {
    PaError err;

    // Khởi tạo PortAudio
    err = Pa_Initialize();
    if (err != paNoError) {
        std::cerr << "PortAudio error: " << Pa_GetErrorText(err) << "\n";
        return 1;
    }

    AudioQueue recordQueue;
    AudioUserData userData;
    userData.recordQueue = &recordQueue;

    // Cấu hình Input (Microphone)
    PaStreamParameters inputParameters;
    inputParameters.device = Pa_GetDefaultInputDevice();
    if (inputParameters.device == paNoDevice) {
        std::cerr << "Error: No default input device.\n";
        Pa_Terminate();
        return 1;
    }
    inputParameters.channelCount = NUM_CHANNELS;
    inputParameters.sampleFormat = paFloat32; // Định dạng mẫu Float 32-bit theo yêu cầu
    inputParameters.suggestedLatency = Pa_GetDeviceInfo(inputParameters.device)->defaultLowInputLatency;
    inputParameters.hostApiSpecificStreamInfo = nullptr;

    // Cấu hình Output (Loa)
    PaStreamParameters outputParameters;
    outputParameters.device = Pa_GetDefaultOutputDevice();
    if (outputParameters.device == paNoDevice) {
        std::cerr << "Error: No default output device.\n";
        Pa_Terminate();
        return 1;
    }
    outputParameters.channelCount = NUM_CHANNELS;
    outputParameters.sampleFormat = paFloat32;
    outputParameters.suggestedLatency = Pa_GetDeviceInfo(outputParameters.device)->defaultLowOutputLatency;
    outputParameters.hostApiSpecificStreamInfo = nullptr;

    // Mở luồng âm thanh Song công (Full-Duplex)
    PaStream* stream;
    err = Pa_OpenStream(
        &stream,
        &inputParameters,
        &outputParameters,
        SAMPLE_RATE,
        FRAMES_PER_BUFFER,
        paClipOff,      // Không cần tự động clip dữ liệu vượt ngưỡng
        paCallback,     // Hàm callback xử lý âm thanh
        &userData       // Con trỏ truyền dữ liệu vào callback
    );

    if (err != paNoError) {
        std::cerr << "Pa_OpenStream error: " << Pa_GetErrorText(err) << "\n";
        Pa_Terminate();
        return 1;
    }

    // Bắt đầu chạy Stream
    err = Pa_StartStream(stream);
    if (err != paNoError) {
        std::cerr << "Pa_StartStream error: " << Pa_GetErrorText(err) << "\n";
        Pa_CloseStream(stream);
        Pa_Terminate();
        return 1;
    }

    std::cout << "[Audio Engine] Stream started successfully at 48000Hz (Mono).\n";
    std::cout << "Gõ lệnh bất kỳ rồi nhấn Enter để dừng ứng dụng...\n";

    // VÒNG LẶP XỬ LÝ CHÍNH (Main Loop / Processing Thread)
    // Thread chính đảm nhận việc rút dữ liệu từ hàng đợi ra để xử lý/mã hóa, 
    // giữ cho Thread của PortAudio luôn nhẹ nhàng và không bị nghẽn mạng.
    bool running = true;

    // Giả lập chạy trong vòng lặp, thực tế bạn có thể tách sang 1 std::thread riêng
    while (running) {
        std::vector<float> audioFrame;

        // Kiểm tra xem có dữ liệu âm thanh thô trong Queue không
        if (recordQueue.pop(audioFrame)) {
            // Đưa frame âm thanh thô đi mã hóa (FFmpeg/Opus) và gửi qua mạng
            encodeAndSendAudio(audioFrame);
        }

        // Nghỉ một khoảng rất ngắn để tránh chiếm 100% CPU khi queue trống
        Pa_Sleep(5);
    }

    // Dọn dẹp tài nguyên khi tắt ứng dụng
    err = Pa_StopStream(stream);
    if (err != paNoError) std::cerr << "Pa_StopStream error: " << Pa_GetErrorText(err) << "\n";

    err = Pa_CloseStream(stream);
    if (err != paNoError) std::cerr << "Pa_CloseStream error: " << Pa_GetErrorText(err) << "\n";

    Pa_Terminate();
    std::cout << "[Audio Engine] Terminated.\n";
    return 0;
}