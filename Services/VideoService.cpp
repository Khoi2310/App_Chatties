#include "VideoService.h"
#include <QDebug>

// Chèn thư viện FFmpeg (Chống dính tên biến C với C++)
extern "C" {
#include <libavcodec/avcodec.h>
#include <libswscale/swscale.h>
#include <libavutil/imgutils.h>
}

VideoService::VideoService(QObject *parent) : QThread(parent), isRunning(false) {}

VideoService::~VideoService() {
    stop();
    wait();
}

void VideoService::stop() {
    isRunning = false;
}

void VideoService::run() {
    isRunning = true;
    cv::VideoCapture cap(0);
    if (!cap.isOpened()) {
        qWarning() << "[Video] Không tìm thấy Camera!";
        return;
    }

    cap.set(cv::CAP_PROP_FRAME_WIDTH, 640);
    cap.set(cv::CAP_PROP_FRAME_HEIGHT, 480);
    cap.set(cv::CAP_PROP_FPS, 30);
    qDebug() << "[Video] Camera đã sẵn sàng (640x480 @ 30FPS).";

    // Khởi tạo FFmpeg H264 Placeholder
    const AVCodec* codec = avcodec_find_encoder(AV_CODEC_ID_H264);
    AVCodecContext* codecCtx = nullptr;
    if (codec) {
        codecCtx = avcodec_alloc_context3(codec);
    }

    cv::Mat frame;
    while (isRunning) {
        cap >> frame;
        if (frame.empty()) continue;

        // [PLACEHOLDER FFmpeg] - Mã hóa H264 tại đây

        // Xử lý hiển thị lên Qt
        cv::cvtColor(frame, frame, cv::COLOR_BGR2RGB);
        QImage img(frame.data, frame.cols, frame.rows, frame.step, QImage::Format_RGB888);
        emit frameReady(img.copy());

        msleep(1000 / 30); // Giữ tốc độ 30 FPS
    }
    
    cap.release();
    if (codecCtx) avcodec_free_context(&codecCtx);
    qDebug() << "[Video] Đã tắt Camera.";
}