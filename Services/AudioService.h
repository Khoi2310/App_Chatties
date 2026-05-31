#ifndef AUDIOSERVICE_H
#define AUDIOSERVICE_H

#include <QThread>
#include <atomic>
#include <portaudio.h>

class AudioService : public QThread {
    Q_OBJECT
public:
    explicit AudioService(QObject *parent = nullptr);
    ~AudioService();
    
    void stop(); // Hàm dùng để ngắt Micro an toàn

protected:
    void run() override; // Chạy trên luồng riêng

private:
    std::atomic<bool> isRunning;
};

#endif // AUDIOSERVICE_H