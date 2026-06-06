#ifndef CHATTIES_VIDEO_MANAGER_H
#define CHATTIES_VIDEO_MANAGER_H

#include <opencv2/opencv.hpp>
#include <vector>
#include <memory>

namespace chatties {
namespace client {

class VideoManager {
public:
    VideoManager();
    ~VideoManager();
    
    bool initialize();
    void shutdown();
    
    bool start_camera();
    bool stop_camera();
    
    bool start_recording();
    bool stop_recording();
    
    cv::Mat get_frame();
    void set_camera_device(int device_id);
    
private:
    cv::VideoCapture camera_;
    cv::Mat current_frame_;
    bool camera_active_;
};

} // namespace client
} // namespace chatties

#endif // CHATTIES_VIDEO_MANAGER_H
