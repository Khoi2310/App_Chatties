#include "AudioService.h"
#include <QDebug>

AudioService::AudioService(QObject *parent) : QThread(parent), isRunning(false) {}

AudioService::~AudioService() {
    stop();
    wait(); // Chờ luồng tắt hẳn để chống memory leak
}

void AudioService::stop() {
    isRunning = false;
}

void AudioService::run() {
    isRunning = true;
    PaError err = Pa_Initialize();
    if (err != paNoError) {
        qWarning() << "[Audio] Lỗi khởi tạo PortAudio:" << Pa_GetErrorText(err);
        return;
    }

    PaStream* stream;
    err = Pa_OpenDefaultStream(&stream, 1, 0, paFloat32, 48000, 256, 
        [](const void* inputBuffer, void* /*outputBuffer*/, unsigned long framesPerBuffer,
           const PaStreamCallbackTimeInfo* /*timeInfo*/, PaStreamCallbackFlags /*statusFlags*/, void* /*userData*/) -> int {
            
            // [PLACEHOLDER FFmpeg/Opus] - Chèn mã hóa âm thanh
            
            return paContinue;
        }, nullptr);

    if (err == paNoError) {
        Pa_StartStream(stream);
        qDebug() << "[Audio] Đã bật Microphone (48000Hz).";
        
        while (isRunning) {
            msleep(100);
        }
        
        Pa_StopStream(stream);
        Pa_CloseStream(stream);
    }
    Pa_Terminate();
    qDebug() << "[Audio] Đã tắt Microphone.";
}