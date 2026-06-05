#ifndef CHATTIES_VIDEO_PROCESSOR_H
#define CHATTIES_VIDEO_PROCESSOR_H

#include <opencv2/opencv.hpp>
#include <vector>
#include <memory>

namespace chatties {
namespace server {

class VideoProcessor {
public:
    VideoProcessor();
    ~VideoProcessor();
    
    bool initialize(int width, int height, int fps);
    void shutdown();
    
    bool start_capture();
    bool stop_capture();
    
    bool start_streaming();
    bool stop_streaming();
    
    cv::Mat get_frame();
    void process_frame(const cv::Mat& frame);
    
    std::vector<uint8_t> encode_frame(const cv::Mat& frame);
    
private:
    cv::VideoCapture capture_;
    cv::Mat current_frame_;
    
    int width_;
    int height_;
    int fps_;
    bool initialized_;
};

} // namespace server
} // namespace chatties

#endif // CHATTIES_VIDEO_PROCESSOR_H
