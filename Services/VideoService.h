#ifndef VIDEOSERVICE_H
#define VIDEOSERVICE_H

#include <QThread>
#include <QImage>
#include <atomic>
#include <opencv2/opencv.hpp>

class VideoService : public QThread {
    Q_OBJECT
public:
    explicit VideoService(QObject *parent = nullptr);
    ~VideoService();
    
    void stop();

signals:
    // Bắn khung hình ảnh lên UI để hiển thị
    void frameReady(QImage image); 

protected:
    void run() override;

private:
    std::atomic<bool> isRunning;
};

#endif // VIDEOSERVICE_H