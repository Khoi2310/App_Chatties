#include <iostream>
#include <thread>
#include <atomic>
#include <queue>
#include <mutex>
#include <vector>

// OpenCV
#include <opencv2/opencv.hpp>

// FFmpeg (Cần bọc trong extern "C")
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>
}

// Cấu hình các tham số Video
const int WIDTH = 640;
const int HEIGHT = 480;
const int FPS = 30;

// ==========================================
// THÀNH PHẦN QUẢN LÝ VIDEO ENCODER (H.264)
// ==========================================
class H264Encoder {
public:
    H264Encoder() : codecContext_(nullptr), swsContext_(nullptr),
        avFrameYUV_(nullptr), avPacket_(nullptr) {}

    ~H264Encoder() {
        cleanup();
    }

    bool initialize() {
        // 1. Tìm Codec H.264 (libx264)
        const AVCodec* codec = avcodec_find_encoder(AV_CODEC_ID_H264);
        if (!codec) {
            std::cerr << "[FFmpeg] Không tìm thấy codec libx264\n";
            return false;
        }

        // 2. Khởi tạo Context
        codecContext_ = avcodec_alloc_context3(codec);
        if (!codecContext_) return false;

        // Cấu hình các thông số mã hóa phù hợp với Video Chat (Low Latency)
        codecContext_->width = WIDTH;
        codecContext_->height = HEIGHT;
        codecContext_->time_base = { 1, FPS };
        codecContext_->framerate = { FPS, 1 };
        codecContext_->pix_fmt = AV_PIX_FMT_YUV420P; // Chuẩn nén H.264 phổ biến
        codecContext_->gop_size = 10;                // Tạo I-frame sau mỗi 10 khung hình để giảm trễ khi mất gói
        codecContext_->max_b_frames = 0;             // KHÔNG dùng B-frame trong real-time video chat (gây độ trễ cao)

        // Cấu hình tham số tối ưu tốc độ cho x264
        av_opt_set(codecContext_->priv_data, "preset", "ultrafast", 0); // Nén nhanh nhất
        av_opt_set(codecContext_->priv_data, "tune", "zerolatency", 0); // Triệt tiêu độ trễ buffer

        // Open codec
        if (avcodec_open2(codecContext_, codec, nullptr) < 0) {
            std::cerr << "[FFmpeg] Không thể mở codec context\n";
            return false;
        }

        // 3. Cấp phát bộ nhớ cho cấu trúc Frame YUV chứa dữ liệu sau chuyển đổi
        avFrameYUV_ = av_frame_alloc();
        avFrameYUV_->format = codecContext_->pix_fmt;
        avFrameYUV_->width = WIDTH;
        avFrameYUV_->height = HEIGHT;

        // Cấp phát mảng byte thực tế cho YUV420p và gán vào avFrameYUV_
        int ret = av_image_alloc(avFrameYUV_->data, avFrameYUV_->linesize,
            WIDTH, HEIGHT, codecContext_->pix_fmt, 32);
        if (ret < 0) return false;

        // 4. Khởi tạo bộ chuyển đổi hệ màu (SwsContext) từ BGR24 (OpenCV) sang YUV420p (FFmpeg)
        swsContext_ = sws_getContext(
            WIDTH, HEIGHT, AV_PIX_FMT_BGR24, // Đầu vào từ OpenCV
            WIDTH, HEIGHT, AV_PIX_FMT_YUV420P, // Đầu ra cho Encoder
            SWS_BILINEAR, nullptr, nullptr, nullptr
        );

        // 5. Khởi tạo Packet chứa dữ liệu sau khi nén thành công
        avPacket_ = av_packet_alloc();

        std::cout << "[FFmpeg] Khởi tạo H.264 Encoder thành công (640x480, 30FPS).\n";
        return true;
    }

    void encodeFrame(const cv::Mat& bgrFrame, int64_t frameIndex) {
        if (bgrFrame.empty() || !codecContext_) return;

        // BƯỚC 1: Chuyển đổi hệ màu từ BGR (OpenCV) sang YUV420p (FFmpeg)
        // Lưu ý: Con trỏ bgrFrame.data được đọc trực tiếp, không copy bộ nhớ
        uint8_t* inData[1] = { bgrFrame.data };
        int inLinesize[1] = { static_cast<int>(bgrFrame.step) };

        sws_scale(swsContext_, inData, inLinesize, 0, HEIGHT,
            avFrameYUV_->data, avFrameYUV_->linesize);

        // Gán mốc thời gian hiển thị (Timestamp) cho Frame
        avFrameYUV_->pts = frameIndex;

        // BƯỚC 2: Gửi Frame YUV thô vào Encoder
        int ret = avcodec_send_frame(codecContext_, avFrameYUV_);
        if (ret < 0) {
            std::cerr << "[FFmpeg] Lỗi gửi frame vào encoder\n";
            return;
        }

        // BƯỚC 3: Vòng lặp lấy các Packet dữ liệu đã nén ra (H.264)
        while (ret >= 0) {
            ret = avcodec_receive_packet(codecContext_, avPacket_);

            // Nếu encoder báo cần thêm dữ liệu đầu vào (EAGAIN) hoặc kết thúc stream (EOF)
            if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
                break;
            }
            else if (ret < 0) {
                std::cerr << "[FFmpeg] Lỗi trong quá trình nhận packet đã nén\n";
                break;
            }

            // -------------------------------------------------------------
            // NƠI BẠN CHÈN MÃ NGUỒN GỬI GÓI TIN QUA MẠNG (TCP/UDP/WebRTC)
            // Dữ liệu nhị phân H.264 nằm ở: avPacket_->data
            // Kích thước gói tin nằm ở:    avPacket_->size
            // -------------------------------------------------------------
            static int encodedCount = 0;
            if (++encodedCount % 90 == 0) { // Tầm 3 giây in log một lần
                std::cout << "[H264 Network Send] Đã nén thành công Packet #" << frameIndex
                    << " | Kích thước gói H.264: " << avPacket_->size << " bytes.\n";
            }

            // GIẢI PHÓNG BỘ NHỚ PACKET BẮT BUỘC: Xóa dữ liệu cũ trong packet để tái sử dụng ở vòng lặp sau
            av_packet_unref(avPacket_);
        }
    }

private:
    void cleanup() {
        if (codecContext_) {
            avcodec_free_context(&codecContext_);
        }
        if (avFrameYUV_) {
            av_freep(&avFrameYUV_->data[0]); // Giải phóng vùng đệm ảnh av_image_alloc
            av_frame_free(&avFrameYUV_);
        }
        if (swsContext_) {
            sws_freeContext(swsContext_);
        }
        if (avPacket_) {
            av_packet_free(&avPacket_);
        }
        std::cout << "[FFmpeg] Đã dọn dẹp sạch toàn bộ tài nguyên bộ nhớ.\n";
    }

    AVCodecContext* codecContext_;
    SwsContext* swsContext_;
    AVFrame* avFrameYUV_;
    AVPacket* avPacket_;
};

// ==========================================
// 2. VÒNG LẶP CAPTURE WEBCAM VÀ ĐIỀU PHỐI LUỒNG
// ==========================================
int main() {
    std::atomic<bool> isRunning(true);
    H264Encoder encoder;

    if (!encoder.initialize()) {
        return -1;
    }

    // Khởi chạy một Worker Thread riêng biệt phục vụ thu hình và nén hình
    std::thread videoThread([&]() {
        // Mở Webcam mặc định
        cv::VideoCapture cap(0);
        if (!cap.isOpened()) {
            std::cerr << "[OpenCV] Không thể kết nối tới Webcam!\n";
            isRunning = false;
            return;
        }

        // Cấu hình cứng độ phân giải cho Webcam
        cap.set(cv::CAP_PROP_FRAME_WIDTH, WIDTH);
        cap.set(cv::CAP_PROP_FRAME_HEIGHT, HEIGHT);
        cap.set(cv::CAP_PROP_FPS, FPS);

        cv::Mat frame;
        int64_t frameIndex = 0;

        // Vòng lặp capture liên tục tần suất ~30 FPS
        while (isRunning) {
            auto startTime = std::chrono::steady_clock::now();

            // Đọc frame hình ảnh từ Webcam (Hệ màu mặc định của OpenCV là BGR)
            cap >> frame;
            if (frame.empty()) continue;

            // Thực hiện chuyển đổi và nén H.264
            encoder.encodeFrame(frame, frameIndex++);

            // Tính toán thời gian ngủ để đảm bảo đúng tốc độ 30 FPS (~33.3ms mỗi frame)
            auto endTime = std::chrono::steady_clock::now();
            auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(endTime - startTime).count();
            long sleepTime = (1000 / FPS) - elapsed;

            if (sleepTime > 0) {
                std::this_thread::sleep_for(std::chrono::milliseconds(sleepTime));
            }
        }

        cap.release();
        std::cout << "[Video Thread] Đã tắt Webcam và giải phóng luồng.\n";
        });

    std::cout << "Hệ thống Video Chat đang chạy ngầm. Nhấn [Enter] để thoát...\n";
    std::cin.get();

    // Dừng luồng an toàn
    isRunning = false;
    if (videoThread.joinable()) {
        videoThread.join();
    }

    return 0;
}